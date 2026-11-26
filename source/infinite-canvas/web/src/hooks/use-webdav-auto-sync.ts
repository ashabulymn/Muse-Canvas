import { useEffect, useRef } from "react";
import { App } from "antd";
import { useTranslation } from "react-i18next";

import i18n from "@/i18n";
import { requestWebdavSync } from "@/services/app-sync";
import { useAssetStore } from "@/stores/use-asset-store";
import { useCanvasStore } from "@/stores/canvas/use-canvas-store";
import { stripApiKeysFromConfig, useConfigStore } from "@/stores/use-config-store";
import { usePromptSourceStore } from "@/stores/use-prompt-source-store";
import { useThemeStore } from "@/stores/use-theme-store";

/** Notification key shared with the manual sync in the settings modal. */
export const WEBDAV_AUTO_SYNC_NOTICE_KEY = "webdav-auto-sync";

const DEBOUNCE_MS = 30_000;
const INTERVAL_MS = 5 * 60_000;
const BACKOFF_MS = [60_000, 5 * 60_000, 15 * 60_000];
const MAX_FAILURES = 3;
const FOLLOW_UP_MS = 2_000;

/** Content fingerprint: everything that must sync, without viewport or updatedAt. */
function contentFingerprint(): string {
    const { projects, deletedProjects } = useCanvasStore.getState();
    const { assets } = useAssetStore.getState();
    const { config } = useConfigStore.getState();
    const { sources, schedule } = usePromptSourceStore.getState();
    return JSON.stringify({
        projects: projects.map((project) => ({
            id: project.id,
            title: project.title,
            createdAt: project.createdAt,
            nodes: project.nodes,
            connections: project.connections,
            chatSessions: project.chatSessions,
            activeChatId: project.activeChatId,
            backgroundMode: project.backgroundMode,
            showImageInfo: project.showImageInfo,
        })),
        deletedProjects,
        assets: assets.map((asset) => ({ ...asset, updatedAt: undefined })),
        settings: {
            config: stripApiKeysFromConfig(config),
            theme: useThemeStore.getState().theme,
            locale: i18n.language === "zh-CN" ? "zh-CN" : "en-US",
            promptSources: { sources, schedule },
        },
    });
}

/** Auto-sync WebDAV: once on open, shortly after local changes, and every 5 minutes. */
export function useWebdavAutoSync() {
    const { notification } = App.useApp();
    const { t } = useTranslation();
    const autoSync = useConfigStore((state) => state.webdav.autoSync);
    const webdavUrl = useConfigStore((state) => state.webdav.url);
    const baselineRef = useRef("");
    const debounceTimerRef = useRef<number | null>(null);
    const failuresRef = useRef(0);
    const stoppedRef = useRef(false);
    const stoppedLastSyncedRef = useRef("");
    const syncingRef = useRef(false);
    const pendingRef = useRef(false);
    const retryAtRef = useRef(0);
    const startedRef = useRef(false);

    useEffect(() => {
        if (!autoSync || !webdavUrl.trim()) return;
        stoppedRef.current = false;
        failuresRef.current = 0;
        retryAtRef.current = 0;
        baselineRef.current = contentFingerprint();

        const maybeResume = () => {
            if (!stoppedRef.current) return;
            if (useConfigStore.getState().webdav.lastSyncedAt === stoppedLastSyncedRef.current) return;
            stoppedRef.current = false;
            failuresRef.current = 0;
            retryAtRef.current = 0;
            baselineRef.current = contentFingerprint();
        };

        const showFailure = (reason: string) => {
            const stopped = failuresRef.current >= MAX_FAILURES;
            notification.open({
                key: WEBDAV_AUTO_SYNC_NOTICE_KEY,
                type: "error",
                message: t(stopped ? "config.webdav.autoSyncStopped" : "config.webdav.autoSyncFailed"),
                description: t(stopped ? "config.webdav.autoSyncStoppedDescription" : "config.webdav.autoSyncFailedDescription", { reason }),
                duration: 0,
            });
        };

        const runSync = async () => {
            if (syncingRef.current) return;
            if (!navigator.onLine) {
                showFailure(t("config.webdav.errors.connectionFailed"));
                return;
            }
            const config = useConfigStore.getState().webdav;
            syncingRef.current = true;
            try {
                const result = await requestWebdavSync(config);
                useConfigStore.getState().updateWebdavConfig("lastSyncedAt", result.syncedAt);
                failuresRef.current = 0;
                retryAtRef.current = 0;
                notification.destroy(WEBDAV_AUTO_SYNC_NOTICE_KEY);
                baselineRef.current = contentFingerprint();
            } catch (error) {
                failuresRef.current += 1;
                retryAtRef.current = Date.now() + BACKOFF_MS[Math.min(failuresRef.current, BACKOFF_MS.length) - 1];
                if (failuresRef.current >= MAX_FAILURES) {
                    stoppedRef.current = true;
                    stoppedLastSyncedRef.current = useConfigStore.getState().webdav.lastSyncedAt;
                }
                showFailure(error instanceof Error ? error.message : t("config.webdav.failed"));
            } finally {
                syncingRef.current = false;
                if (pendingRef.current) {
                    pendingRef.current = false;
                    schedule(FOLLOW_UP_MS);
                }
            }
        };

        const schedule = (delay: number) => {
            if (stoppedRef.current) return;
            if (debounceTimerRef.current) window.clearTimeout(debounceTimerRef.current);
            debounceTimerRef.current = window.setTimeout(() => {
                debounceTimerRef.current = null;
                if (stoppedRef.current) return;
                if (Date.now() < retryAtRef.current) {
                    schedule(retryAtRef.current - Date.now());
                    return;
                }
                if (contentFingerprint() === baselineRef.current) return;
                void runSync();
            }, delay);
        };

        const onStoreChange = () => {
            maybeResume();
            if (stoppedRef.current) return;
            if (syncingRef.current) {
                pendingRef.current = true;
                return;
            }
            if (contentFingerprint() === baselineRef.current) return;
            schedule(DEBOUNCE_MS);
        };

        if (!startedRef.current) {
            startedRef.current = true;
            void runSync();
        }
        const unsubscribeCanvas = useCanvasStore.subscribe(onStoreChange);
        const unsubscribeAssets = useAssetStore.subscribe(onStoreChange);
        const unsubscribeConfig = useConfigStore.subscribe(onStoreChange);
        const unsubscribeTheme = useThemeStore.subscribe(onStoreChange);
        const unsubscribePromptSources = usePromptSourceStore.subscribe(onStoreChange);
        const interval = window.setInterval(() => {
            maybeResume();
            if (stoppedRef.current || syncingRef.current) return;
            if (Date.now() < retryAtRef.current) return;
            if (contentFingerprint() === baselineRef.current) return;
            void runSync();
        }, INTERVAL_MS);

        return () => {
            unsubscribeCanvas();
            unsubscribeAssets();
            unsubscribeConfig();
            unsubscribeTheme();
            unsubscribePromptSources();
            window.clearInterval(interval);
            if (debounceTimerRef.current) window.clearTimeout(debounceTimerRef.current);
            debounceTimerRef.current = null;
            startedRef.current = false;
            notification.destroy(WEBDAV_AUTO_SYNC_NOTICE_KEY);
        };
    }, [autoSync, webdavUrl, notification, t]);
}

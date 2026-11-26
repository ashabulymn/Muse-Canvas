import { create } from "zustand";
import { persist } from "zustand/middleware";

import { DEFAULT_PROMPT_SOURCES, createPromptSource, type PromptSource } from "@/services/api/prompt-source-presets";
import { touchSettingsUpdatedAt } from "@/stores/use-config-store";

export type PromptSourceSchedule = {
    intervalMinutes: number;
    lastFetchedAt: string;
};

const PROMPT_SOURCE_STORE_KEY = "infinite-canvas:prompt_source_store_v2";

const defaultSchedule: PromptSourceSchedule = {
    intervalMinutes: 30,
    lastFetchedAt: "",
};

export const PROMPT_SOURCE_INTERVALS = [0, 30, 60, 360, 1440];

/** Built-ins always come from the defaults; only their enabled flags and custom sources are local state. */
function normalizePromptSources(savedSources: PromptSource[], savedSchedule?: Partial<PromptSourceSchedule>) {
    const enabledById = new Map(savedSources.map((source) => [source.id, source.enabled]));
    const builtIn = DEFAULT_PROMPT_SOURCES.map((source) => ({ ...source, enabled: enabledById.get(source.id) ?? source.enabled }));
    const custom = savedSources.filter((source) => !source.builtIn).map((source) => createPromptSource(source));
    return { sources: [...builtIn, ...custom], schedule: { ...defaultSchedule, ...(savedSchedule || {}) } };
}

type PromptSourceStore = {
    sources: PromptSource[];
    schedule: PromptSourceSchedule;
    addSource: () => PromptSource;
    saveSource: (source: PromptSource) => void;
    removeSource: (id: string) => void;
    toggleSource: (id: string, enabled: boolean) => void;
    updateSchedule: <K extends keyof PromptSourceSchedule>(key: K, value: PromptSourceSchedule[K]) => void;
    /** Replace all sources with settings downloaded from WebDAV; does not bump the settings clock. */
    replaceSyncedSources: (sources: PromptSource[], schedule: PromptSourceSchedule) => void;
};

export const usePromptSourceStore = create<PromptSourceStore>()(
    persist(
        (set) => ({
            sources: DEFAULT_PROMPT_SOURCES,
            schedule: defaultSchedule,
            addSource: () => createPromptSource(),
            saveSource: (source) => {
                touchSettingsUpdatedAt();
                set((state) => ({
                    sources: state.sources.some((item) => item.id === source.id)
                        ? state.sources.map((item) => (item.id === source.id && !item.builtIn ? createPromptSource(source) : item))
                        : [...state.sources, createPromptSource(source)],
                }));
            },
            removeSource: (id) => {
                touchSettingsUpdatedAt();
                set((state) => ({ sources: state.sources.filter((item) => item.id !== id || item.builtIn) }));
            },
            toggleSource: (id, enabled) => {
                touchSettingsUpdatedAt();
                set((state) => ({ sources: state.sources.map((item) => (item.id === id ? { ...item, enabled } : item)) }));
            },
            updateSchedule: (key, value) => {
                touchSettingsUpdatedAt();
                set((state) => ({ schedule: { ...state.schedule, [key]: value } }));
            },
            replaceSyncedSources: (sources, schedule) => set(() => normalizePromptSources(Array.isArray(sources) ? sources : [], schedule)),
        }),
        {
            name: PROMPT_SOURCE_STORE_KEY,
            partialize: (state) => ({ sources: state.sources, schedule: state.schedule }),
            merge: (persisted, current) => {
                const persistedState = (persisted || {}) as Partial<PromptSourceStore>;
                const savedSources = Array.isArray(persistedState.sources) ? persistedState.sources : [];
                return { ...current, ...normalizePromptSources(savedSources, persistedState.schedule) };
            },
        },
    ),
);

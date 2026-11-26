import { create } from "zustand";
import { persist } from "zustand/middleware";

import { touchSettingsUpdatedAt } from "@/stores/use-config-store";

export type ThemeName = "light" | "dark";

type ThemeStore = {
    theme: ThemeName;
    setTheme: (theme: ThemeName) => void;
};

export const useThemeStore = create<ThemeStore>()(
    persist(
        (set) => ({
            theme: "dark",
            setTheme: (theme) => {
                touchSettingsUpdatedAt();
                set({ theme });
            },
        }),
        { name: "infinite-canvas:theme_store" },
    ),
);

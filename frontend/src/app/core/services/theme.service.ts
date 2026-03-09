import { Injectable, signal, effect, Renderer2, RendererFactory2 } from "@angular/core";

const STORAGE_KEY = "theme-dark";

@Injectable({ providedIn: "root" })
export class ThemeService {
  private readonly renderer: Renderer2;

  readonly isDark = signal(this.loadPreference());

  constructor(rendererFactory: RendererFactory2) {
    this.renderer = rendererFactory.createRenderer(null, null);

    // Apply on creation (app startup) and react to future changes
    effect(() => {
      const dark = this.isDark();
      if (dark) {
        this.renderer.addClass(document.body, "dark-theme");
      } else {
        this.renderer.removeClass(document.body, "dark-theme");
      }
      localStorage.setItem(STORAGE_KEY, JSON.stringify(dark));
    });
  }

  toggle(): void {
    this.isDark.set(!this.isDark());
  }

  private loadPreference(): boolean {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored !== null) {
      return JSON.parse(stored) === true;
    }
    // Fall back to system preference
    return globalThis.matchMedia("(prefers-color-scheme: dark)").matches;
  }
}

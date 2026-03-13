import {
  Component,
  inject,
  signal,
  model,
  computed,
  OnInit,
  ChangeDetectionStrategy,
} from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';
import { AppsService, RemoteApp } from '../../core/services/apps.service';

interface AppGroup {
  name: string;
  apps: RemoteApp[];
}

@Component({
  selector: 'app-fusion-apps',
  imports: [FormsModule],
  templateUrl: './fusion-apps.html',
  styleUrl: './fusion-apps.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class FusionAppsComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly appsService = inject(AppsService);
  private readonly router = inject(Router);

  private readonly iconColors: readonly string[] = [
    'linear-gradient(180deg, #2b6dd8, #1f4ea3)',
    'linear-gradient(180deg, #1f8d58, #16663f)',
    'linear-gradient(180deg, #d96a37, #ac4a1f)',
    'linear-gradient(180deg, #4273e2, #2b4fa8)',
    'linear-gradient(180deg, #8a4fe0, #6d2fc7)',
    'linear-gradient(180deg, #e0574b, #c43f35)',
    'linear-gradient(180deg, #2ab3b0, #1b8785)',
    'linear-gradient(180deg, #2aa3c9, #1d6da0)',
    'linear-gradient(180deg, #63748f, #45516a)',
    'linear-gradient(180deg, #d74e4f, #b43c3d)',
  ];

  user = this.auth.getUser();
  searchQuery = model('');
  allGroups = signal<AppGroup[]>([]);
  isLoading = signal(false);
  launchNote = signal('');
  brokenIcons = signal(new Set<string>());

  filteredGroups = computed(() => {
    const q = this.searchQuery().toLowerCase().trim();
    if (!q) return this.allGroups();
    return this.allGroups()
      .map((g) => ({
        ...g,
        apps: g.apps.filter((a) => a.name.toLowerCase().includes(q)),
      }))
      .filter((g) => g.apps.length > 0);
  });

  ngOnInit(): void {
    this.loadApps();
  }

  loadApps(): void {
    this.isLoading.set(true);
    this.appsService.getApps().subscribe({
      next: ({ apps, desktops }) => {
        const combined = [...apps, ...desktops];
        const grouped = combined.reduce(
          (acc, app) => {
            const key = app.folderName || 'Aplicaciones';
            if (!acc[key]) {
              acc[key] = [];
            }
            acc[key].push(app);
            return acc;
          },
          {} as Record<string, RemoteApp[]>,
        );
        this.allGroups.set(
          Object.entries(grouped).map(([name, appsInGroup]) => ({ name, apps: appsInGroup })),
        );
        this.isLoading.set(false);
      },
      error: () => this.isLoading.set(false),
    });
  }

  launch(app: RemoteApp): void {
    this.launchNote.set(`Iniciando ${app.name} en sesión remota...`);
    this.appsService.launchApp(app.alias);
  }

  logout(): void {
    this.auth.logout().subscribe({
      next: () => this.router.navigate(['/login']),
    });
  }

  getInitial(name: string): string {
    return name.charAt(0).toUpperCase();
  }

  getIconColor(name: string): string {
    let hash = 0;
    for (let i = 0; i < name.length; i++) {
      hash = Math.trunc(hash * 31 + (name.codePointAt(i) ?? 0));
    }
    return this.iconColors[Math.abs(hash) % this.iconColors.length];
  }

  getIconUrl(app: RemoteApp): string | null {
    if (app.alias && !this.brokenIcons().has(app.alias)) {
      return app.alias + '.png';
    }
    return null;
  }

  onIconError(app: RemoteApp): void {
    this.brokenIcons.update((set) => new Set(set).add(app.alias));
  }
}

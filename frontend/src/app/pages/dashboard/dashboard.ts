import { Component, OnInit, inject, ChangeDetectionStrategy, signal, model } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { AppsService, RemoteApp } from '../../core/services/apps.service';

interface AppGroup {
  name: string;
  apps: RemoteApp[];
}

@Component({
  selector: 'app-dashboard',
  imports: [FormsModule],
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly appsService = inject(AppsService);

  user = this.auth.getUser();
  loading = signal(true);
  error = signal('');
  searchQuery = model('');
  isDark = signal(true);

  private allGroups: AppGroup[] = [];
  filteredGroups: AppGroup[] = [];

  ngOnInit() {
    // Restaurar tema guardado
    const saved = localStorage.getItem('rdweb-theme') || 'dark';
    this.isDark.set(saved === 'dark');
    document.body.dataset['theme'] = saved;
    this.loadApps();
  }

  toggleTheme() {
    this.isDark.set(!this.isDark());
    const theme = this.isDark() ? 'dark' : 'light';
    document.body.dataset['theme'] = theme;
    localStorage.setItem('rdweb-theme', theme);
  }

  launch(alias: string) {
    this.appsService.launchApp(alias);
  }

  loadApps() {
    this.loading.set(true);
    this.error.set('');
    this.appsService.getApps().subscribe({
      next: ({ apps, desktops }) => {
        const combined = [...apps, ...desktops];
        const grouped = combined.reduce(
          (acc, app) => {
            const key = app.folderName || 'Aplicaciones';
            if (!acc[key]) acc[key] = [];
            acc[key].push(app);
            return acc;
          },
          {} as Record<string, RemoteApp[]>,
        );
        this.allGroups = Object.entries(grouped).map(([name, apps]) => ({ name, apps }));
        this.filteredGroups = [...this.allGroups];
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err?.error?.error || 'No se pudo conectar al servidor.');
        this.loading.set(false);
      },
    });
  }

  onSearch() {
    const q = this.searchQuery().toLowerCase().trim();
    if (q) {
      this.filteredGroups = this.allGroups
        .map((g) => ({ ...g, apps: g.apps.filter((a) => a.name.toLowerCase().includes(q)) }))
        .filter((g) => g.apps.length > 0);
    } else {
      this.filteredGroups = [...this.allGroups];
    }
  }

  logout() {
    this.auth.logout().subscribe();
  }
}

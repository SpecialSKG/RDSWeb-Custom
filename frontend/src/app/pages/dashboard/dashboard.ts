import { Component, OnInit, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/services/auth.service';
import { AppsService, RemoteApp } from '../../core/services/apps.service';

interface AppGroup { name: string; apps: RemoteApp[]; }

@Component({
    selector: 'app-dashboard',
    standalone: true,
    changeDetection: ChangeDetectionStrategy.OnPush,
    imports: [FormsModule],
    templateUrl: './dashboard.html',
    styleUrl: './dashboard.css',
})
export class DashboardComponent implements OnInit {
    private auth = inject(AuthService);
    private appsService = inject(AppsService);
    private cdr = inject(ChangeDetectorRef);

    user = this.auth.user;
    loading = true;
    error = '';
    searchQuery = '';
    isDark = true;

    private allGroups: AppGroup[] = [];
    filteredGroups: AppGroup[] = [];

    ngOnInit() {
        // Restaurar tema guardado
        const saved = localStorage.getItem('rdweb-theme') || 'dark';
        this.isDark = saved === 'dark';
        document.body.setAttribute('data-theme', saved);
        this.loadApps();
    }

    toggleTheme() {
        this.isDark = !this.isDark;
        const theme = this.isDark ? 'dark' : 'light';
        document.body.setAttribute('data-theme', theme);
        localStorage.setItem('rdweb-theme', theme);
        this.cdr.detectChanges();
    }

    launch(alias: string) {
        this.appsService.launchApp(alias);
    }

    loadApps() {
        this.loading = true;
        this.error = '';
        this.cdr.detectChanges();
        this.appsService.getApps().subscribe({
            next: ({ apps, desktops }) => {
                const combined = [...apps, ...desktops];
                const grouped = combined.reduce((acc, app) => {
                    const key = app.folderName || 'Aplicaciones';
                    if (!acc[key]) acc[key] = [];
                    acc[key].push(app);
                    return acc;
                }, {} as Record<string, RemoteApp[]>);
                this.allGroups = Object.entries(grouped).map(([name, apps]) => ({ name, apps }));
                this.filteredGroups = [...this.allGroups];
                this.loading = false;
                this.cdr.detectChanges();
            },
            error: (err) => {
                this.error = err?.error?.error || 'No se pudo conectar al servidor.';
                this.loading = false;
                this.cdr.detectChanges();
            },
        });
    }

    onSearch() {
        const q = this.searchQuery.toLowerCase().trim();
        if (!q) { this.filteredGroups = [...this.allGroups]; }
        else {
            this.filteredGroups = this.allGroups
                .map((g) => ({ ...g, apps: g.apps.filter((a) => a.name.toLowerCase().includes(q)) }))
                .filter((g) => g.apps.length > 0);
        }
        this.cdr.detectChanges();
    }

    logout() {
        this.auth.logout().subscribe();
    }
}

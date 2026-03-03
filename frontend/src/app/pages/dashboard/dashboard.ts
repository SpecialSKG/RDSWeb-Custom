import { Component, OnInit, inject, ChangeDetectorRef, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { AuthService } from '../../core/services/auth.service';
import { AppsService, RemoteApp } from '../../core/services/apps.service';

interface AppGroup { name: string; apps: RemoteApp[]; }

// ── Mapa de iconos por alias de aplicación ───────────────────────────────────
const ICON_MAP: Record<string, string> = {
    MSWORD: 'description',
    MSEXCEL: 'table_chart',
    MSPOWERPOINT: 'slideshow',
    NOTEPADPP: 'code',
    CHROME: 'language',
    FIREFOX: 'public',
    EDGE: 'travel_explore',
    ERP: 'business',
    CRM: 'people',
    SAP: 'account_tree',
    DESKTOP_DEFAULT: 'computer',
    PUTTY: 'terminal',
    FILEZILLA: 'folder_zip',
    ACROBAT: 'picture_as_pdf',
    AUTOCAD: 'architecture',
};

// ── Color de fondo del icono por tipo ────────────────────────────────────────
const COLOR_MAP: Record<string, string> = {
    MSWORD: 'blue',
    MSEXCEL: 'green',
    MSPOWERPOINT: 'orange',
    NOTEPADPP: 'teal',
    CHROME: 'yellow',
    FIREFOX: 'orange',
    EDGE: 'blue',
    ERP: 'purple',
    CRM: 'pink',
    SAP: 'indigo',
    DESKTOP_DEFAULT: 'gray',
    PUTTY: 'teal',
    ACROBAT: 'red',
    AUTOCAD: 'cyan',
};

@Component({
    selector: 'app-dashboard',
    standalone: true,
    changeDetection: ChangeDetectionStrategy.OnPush,
    imports: [CommonModule, FormsModule, MatFormFieldModule, MatInputModule, MatButtonModule, MatIconModule, MatProgressSpinnerModule, MatSnackBarModule],
    templateUrl: './dashboard.html',
    styleUrl: './dashboard.css',
})
export class DashboardComponent implements OnInit {
    private auth = inject(AuthService);
    private appsService = inject(AppsService);
    private snackBar = inject(MatSnackBar);
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

    getIconForApp(alias: string, name: string): string {
        const key = alias?.toUpperCase();
        if (ICON_MAP[key]) return ICON_MAP[key];
        // Fallback por palabras en el nombre
        const n = name?.toLowerCase() || '';
        if (n.includes('word') || n.includes('texto')) return 'description';
        if (n.includes('excel') || n.includes('hoja')) return 'table_chart';
        if (n.includes('power') || n.includes('present')) return 'slideshow';
        if (n.includes('chrome') || n.includes('firefox') || n.includes('browser')) return 'language';
        if (n.includes('code') || n.includes('notepad')) return 'code';
        if (n.includes('erp') || n.includes('sistema') || n.includes('sap')) return 'business';
        if (n.includes('escritorio') || n.includes('desktop')) return 'computer';
        if (n.includes('pdf') || n.includes('acrobat')) return 'picture_as_pdf';
        return 'apps';
    }

    getIconColor(alias: string): string {
        return COLOR_MAP[alias?.toUpperCase()] || 'accent';
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

    launch(alias: string) {
        this.snackBar.open('Abriendo aplicación...', '', { duration: 2000 });
        this.appsService.launchApp(alias);
    }

    logout() {
        this.auth.logout().subscribe();
    }
}

import {
  Component,
  OnInit,
  inject,
  ChangeDetectionStrategy,
  signal,
  model,
  computed,
} from "@angular/core";
import { FormsModule } from "@angular/forms";
import { AuthService } from "../../core/services/auth.service";
import { AppsService, RemoteApp } from "../../core/services/apps.service";
import { ThemeService } from "../../core/services/theme.service";
import { MatToolbarModule } from "@angular/material/toolbar";
import { MatIconModule } from "@angular/material/icon";
import { MatButtonModule } from "@angular/material/button";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatInputModule } from "@angular/material/input";
import { MatCardModule } from "@angular/material/card";
import { MatListModule } from "@angular/material/list";
import { MatDividerModule } from "@angular/material/divider";
import { MatProgressSpinnerModule } from "@angular/material/progress-spinner";

interface AppGroup {
  name: string;
  apps: RemoteApp[];
}

@Component({
  selector: "app-dashboard",
  imports: [
    MatCardModule,
    MatToolbarModule,
    MatButtonModule,
    MatIconModule,
    FormsModule,
    MatInputModule,
    MatFormFieldModule,
    MatListModule,
    MatDividerModule,
    MatProgressSpinnerModule,
  ],
  templateUrl: "./dashboard.html",
  styleUrl: "./dashboard.scss",
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class DashboardComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly appsService = inject(AppsService);
  private readonly theme = inject(ThemeService);

  isDark = this.theme.isDark;

  user = this.auth.getUser();
  searchQuery = model("");

  allGroups = signal<AppGroup[]>([]);
  filteredGroups = computed(() => {
    const q = this.searchQuery().toLowerCase().trim();
    return this.allGroups()
      .map((g) => ({ ...g, apps: g.apps.filter((a) => a.name.toLowerCase().includes(q)) }))
      .filter((g) => g.apps.length > 0);
  });

  isLoading = signal(false);

  ngOnInit() {
    this.loadApps();
  }

  loadApps() {
    this.isLoading.set(true);
    this.appsService.getApps().subscribe({
      next: ({ apps, desktops }) => {
        const combined = [...apps, ...desktops];
        const grouped = combined.reduce(
          (acc, app) => {
            const key = app.folderName || "Aplicaciones";
            if (!acc[key]) acc[key] = [];
            acc[key].push(app);
            return acc;
          },
          {} as Record<string, RemoteApp[]>,
        );
        this.allGroups.set(Object.entries(grouped).map(([name, apps]) => ({ name, apps })));
        this.isLoading.set(false);
      },
      error: (err) => {
        this.isLoading.set(false);
      },
    });
  }

  launch(alias: string) {
    this.appsService.launchApp(alias);
  }

  toggleTheme(): void {
    this.theme.toggle();
  }

  logout() {
    this.auth.logout().subscribe();
  }
}

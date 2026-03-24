import { inject, Injectable } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { environment } from "../../../environments/environment";

export interface RemoteApp {
  alias: string;
  name: string;
  rdpPath: string | null;
  remoteServer: string;
  folderName: string;
  iconIndex: number;
}

export interface AppResponse {
  ok: boolean;
  apps: RemoteApp[];
  desktops: RemoteApp[];
}

@Injectable({ providedIn: "root" })
export class AppsService {
  private readonly http = inject(HttpClient);

  getApps() {
    return this.http.get<AppResponse>(`${environment.apiUrl}/apps`);
  }

  getLaunchUrl(alias: string): string {
    return `${environment.apiUrl}/launch/${alias}`;
  }

  launchApp(alias: string) {
    // 1. Usar HTTP Client con responseType 'blob' para incluir el Token JWT
    return this.http.get(this.getLaunchUrl(alias), { responseType: "blob" });
  }
}

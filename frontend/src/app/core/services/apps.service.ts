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

  launchApp(alias: string): void {
    // 1. Usar HTTP Client con responseType 'blob' para incluir el Token JWT
    this.http.get(this.getLaunchUrl(alias), { responseType: "blob" }).subscribe({
      next: (blob: Blob) => {
        // 2. Crear una URL local temporal para el archivo binario
        const url = globalThis.URL.createObjectURL(blob);
        const a = document.createElement("a");
        a.href = url;
        a.download = `${alias}.rdp`;
        document.body.appendChild(a);
        a.click();

        // 3. Limpieza
        a.remove();
        globalThis.URL.revokeObjectURL(url);
      },
      error: (err) => {
        console.error("Error al descargar el archivo RDP:", err);
        // Aquí puedes mostrar un mensaje de error en la UI
      },
    });
  }
}

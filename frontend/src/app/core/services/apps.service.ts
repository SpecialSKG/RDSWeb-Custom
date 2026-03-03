import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

export interface RemoteApp {
    alias: string;
    name: string;
    rdpPath: string | null;
    remoteServer: string;
    folderName: string;
    iconIndex: number;
}

@Injectable({ providedIn: 'root' })
export class AppsService {
    constructor(private http: HttpClient) { }

    getApps() {
        return this.http.get<{ ok: boolean; apps: RemoteApp[]; desktops: RemoteApp[] }>(
            `${environment.apiUrl}/apps`,
            { withCredentials: true }
        );
    }

    getLaunchUrl(alias: string): string {
        return `${environment.apiUrl}/launch/${alias}`;
    }

    launchApp(alias: string): void {
        // Crear link temporal y hacer click para descarga del .rdp
        const a = document.createElement('a');
        a.href = this.getLaunchUrl(alias);
        a.download = `${alias}.rdp`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }
}

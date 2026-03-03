import { Injectable, signal } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { tap, catchError, throwError } from 'rxjs';
import { environment } from '../../../environments/environment';

export interface User {
    username: string;
    displayName: string;
    email: string;
    domain: string;
    initials: string;
    privateMode?: boolean;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
    private _user = signal<User | null>(null);
    readonly user = this._user.asReadonly();

    constructor(private http: HttpClient, private router: Router) { }

    login(username: string, password: string, privateMode: boolean) {
        return this.http
            .post<{ ok: boolean; user: User }>(
                `${environment.apiUrl}/auth/login`,
                { username, password, privateMode },
                { withCredentials: true }
            )
            .pipe(
                tap((res) => this._user.set(res.user)),
                catchError((err) => throwError(() => err.error || { error: 'Error de conexión' }))
            );
    }

    logout() {
        return this.http
            .post(`${environment.apiUrl}/auth/logout`, {}, { withCredentials: true })
            .pipe(tap(() => { this._user.set(null); this.router.navigate(['/login']); }));
    }

    fetchMe() {
        return this.http
            .get<User>(`${environment.apiUrl}/auth/me`, { withCredentials: true })
            .pipe(tap((u) => this._user.set(u)));
    }

    isAuthenticated(): boolean {
        return this._user() !== null;
    }
}

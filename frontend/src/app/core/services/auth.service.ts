import { inject, Injectable, signal } from '@angular/core';
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

export interface LoginResponse {
  ok: boolean;
  user: User;
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);

  private readonly user = signal<User | null>(null);

  getUser() {
    return this.user.asReadonly();
  }

  login(username: string, password: string, privateMode: boolean) {
    return this.http
      .post<LoginResponse>(
        `${environment.apiUrl}/auth/login`,
        { username, password, privateMode },
        { withCredentials: true },
      )
      .pipe(
        tap((res) => this.user.set(res.user)),
        catchError((err) => throwError(() => err.error || { error: 'Error de conexión' })),
      );
  }

  logout() {
    return this.http.post(`${environment.apiUrl}/auth/logout`, {}, { withCredentials: true }).pipe(
      tap(() => {
        this.user.set(null);
        this.router.navigate(['/login']);
      }),
    );
  }

  fetchMe() {
    return this.http
      .get<User>(`${environment.apiUrl}/auth/me`, { withCredentials: true })
      .pipe(tap((u) => this.user.set(u)));
  }

  isAuthenticated(): boolean {
    return this.user() !== null;
  }
}

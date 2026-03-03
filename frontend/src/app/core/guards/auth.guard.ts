import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { catchError, map, of } from 'rxjs';

export const authGuard: CanActivateFn = () => {
    const auth = inject(AuthService);
    const router = inject(Router);

    if (auth.isAuthenticated()) return true;

    // Intentar recuperar sesión desde la cookie
    return auth.fetchMe().pipe(
        map(() => true),
        catchError(() => { router.navigate(['/login']); return of(false); })
    );
};

export const guestGuard: CanActivateFn = () => {
    const auth = inject(AuthService);
    const router = inject(Router);
    if (auth.isAuthenticated()) { router.navigate(['/dashboard']); return false; }
    return true;
};

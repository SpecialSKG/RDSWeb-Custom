import { Routes } from '@angular/router';
import { authGuard, guestGuard } from './core/guards/auth.guard';

export const routes: Routes = [
    { path: '', redirectTo: 'dashboard', pathMatch: 'full' },
    {
        path: 'login',
        canActivate: [guestGuard],
        loadComponent: () => import('./pages/login/login').then((m) => m.LoginComponent),
    },
    {
        path: 'dashboard',
        canActivate: [authGuard],
        loadComponent: () => import('./pages/dashboard/dashboard').then((m) => m.DashboardComponent),
    },
    { path: '**', redirectTo: 'dashboard' },
];

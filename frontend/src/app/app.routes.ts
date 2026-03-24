import { Routes } from "@angular/router";
import { authGuard } from "./core/guards/auth.guard";
import { loginGuard } from "./core/guards/login.guard";

export const routes: Routes = [
  {
    path: "login",
    canActivate: [loginGuard],
    loadComponent: () => import("./pages/login/login").then((m) => m.LoginComponent),
  },
  {
    path: "apps",
    canActivate: [authGuard],
    loadComponent: () => import("./pages/apps/apps").then((m) => m.AppsComponent),
  },
  { path: "**", redirectTo: "apps" },
];

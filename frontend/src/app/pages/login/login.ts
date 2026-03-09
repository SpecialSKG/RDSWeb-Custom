import { Component, inject, signal } from "@angular/core";
import {
  FormsModule,
  NonNullableFormBuilder,
  ReactiveFormsModule,
  Validators,
} from "@angular/forms";
import { Router } from "@angular/router";
import { AuthService } from "../../core/services/auth.service";
import { MatCardModule } from "@angular/material/card";
import { MatFormFieldModule } from "@angular/material/form-field";
import { MatInputModule } from "@angular/material/input";
import { MatButtonModule } from "@angular/material/button";
import { MatIconModule } from "@angular/material/icon";

@Component({
  selector: "app-login",
  imports: [
    MatCardModule,
    FormsModule,
    ReactiveFormsModule,
    MatIconModule,
    MatInputModule,
    MatFormFieldModule,
    MatButtonModule,
  ],
  templateUrl: "./login.html",
  styleUrl: "./login.scss",
})
export class LoginComponent {
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);
  private readonly fb = inject(NonNullableFormBuilder);

  loginForm = this.fb.group({
    username: ["", [Validators.required]],
    password: ["", [Validators.required, Validators.minLength(8)]],
  });

  showPassword = signal(false);
  loading = signal(false);

  onSubmit() {
    if (!this.loginForm.valid) return;
    this.loading.set(true);

    this.authService.login(this.loginForm.value).subscribe({
      next: () => {
        this.router.navigate(["dashboard"]);
      },
      error: (err) => {
        this.loading.set(false);
      },
    });
  }
}

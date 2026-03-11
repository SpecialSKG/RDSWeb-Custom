import { Component, inject, signal, OnInit } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-fusion-login',
  imports: [ReactiveFormsModule],
  templateUrl: './fusion-login.html',
  styleUrl: './fusion-login.scss',
})
export class FusionLoginComponent implements OnInit {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly fb = inject(NonNullableFormBuilder);

  loginForm = this.fb.group({
    username: ['', [Validators.required]],
    password: ['', [Validators.required]],
  });

  showPreloader = signal(true);
  passwordVisible = signal(false);
  loading = signal(false);
  errorMessage = signal('');

  ngOnInit(): void {
    setTimeout(() => this.showPreloader.set(false), 700);
  }

  togglePassword(): void {
    this.passwordVisible.update((v) => !v);
  }

  onSubmit(): void {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.loading.set(true);
    this.errorMessage.set('');

    this.auth.login(this.loginForm.getRawValue()).subscribe({
      next: () => this.router.navigate(['/fusion-apps']),
      error: (err) => {
        this.loading.set(false);
        this.errorMessage.set(err?.error || 'Credenciales incorrectas');
      },
    });
  }
}

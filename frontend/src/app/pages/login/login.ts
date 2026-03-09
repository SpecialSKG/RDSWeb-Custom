import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

@Component({
  selector: 'app-login',
  imports: [FormsModule],
  templateUrl: './login.html',
  styleUrl: './login.scss',
})
export class LoginComponent {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  username = signal('administrador');
  password = signal('Admin1234!');
  showPassword = signal(false);
  isPublic = signal(false);
  loading = signal(false);
  errorMessage = signal('');

  onSubmit() {
    if (!this.username() || !this.password()) return;
    this.loading.set(true);
    this.errorMessage.set('');

    this.auth.login(this.username(), this.password(), !this.isPublic()).subscribe({
      next: () => {
        this.router.navigate(['/dashboard']);
      },
      error: (err) => {
        this.errorMessage.set(err?.error || 'Error al iniciar sesión. Intenta de nuevo.');
        this.loading.set(false);
      },
    });
  }
}

import { Component } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../core/services/auth.service';

@Component({
    selector: 'app-login',
    standalone: true,
    imports: [FormsModule],
    templateUrl: './login.html',
    styleUrl: './login.css',
})
export class LoginComponent {
    username = 'administrador';
    password = 'Admin1234!';
    showPassword = false;
    isPublic = false;
    loading = false;
    errorMessage = '';

    constructor(private auth: AuthService, private router: Router) { }

    onSubmit() {
        if (!this.username || !this.password) return;
        this.loading = true;
        this.errorMessage = '';

        this.auth.login(this.username, this.password, !this.isPublic).subscribe({
            next: () => this.router.navigate(['/dashboard']),
            error: (err) => {
                this.errorMessage = err?.error || 'Error al iniciar sesión. Intenta de nuevo.';
                this.loading = false;
            },
        });
    }
}

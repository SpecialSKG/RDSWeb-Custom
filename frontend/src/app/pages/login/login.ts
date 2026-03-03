import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressSpinnerModule } from '@angular/material/progress-spinner';
import { AuthService } from '../../core/services/auth.service';

@Component({
    selector: 'app-login',
    standalone: true,
    imports: [CommonModule, FormsModule, MatFormFieldModule, MatInputModule, MatButtonModule, MatIconModule, MatProgressSpinnerModule],
    templateUrl: './login.html',
    styleUrl: './login.css',
})
export class LoginComponent {
    username = '';
    password = '';
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

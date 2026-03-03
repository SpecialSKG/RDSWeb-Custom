import { HttpInterceptorFn } from '@angular/common/http';

/**
 * Interceptor global que agrega withCredentials: true a TODAS las peticiones HTTP.
 * Esto es necesario para que el navegador envíe la cookie HttpOnly rdweb_token
 * en peticiones cross-origin (ej: frontend :4200 → backend :3000).
 */
export const credentialsInterceptor: HttpInterceptorFn = (req, next) => {
    const authReq = req.clone({ withCredentials: true });
    return next(authReq);
};

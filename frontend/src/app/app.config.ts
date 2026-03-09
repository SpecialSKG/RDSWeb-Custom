import { ApplicationConfig, provideBrowserGlobalErrorListeners } from "@angular/core";
import { provideRouter } from "@angular/router";
import { provideHttpClient, withInterceptors } from "@angular/common/http";
import { routes } from "./app.routes";
import { credentialsInterceptor } from "./core/interceptors/credentials.interceptor";
import { MAT_FORM_FIELD_DEFAULT_OPTIONS } from "@angular/material/form-field";
import { MAT_INPUT_CONFIG } from "@angular/material/input";
import { MAT_BUTTON_CONFIG } from "@angular/material/button";
import { MAT_CARD_CONFIG } from "@angular/material/card";

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(withInterceptors([credentialsInterceptor])),
    {
      provide: MAT_FORM_FIELD_DEFAULT_OPTIONS,
      useValue: {
        appearance: "outline",
      },
    },
    {
      provide: MAT_INPUT_CONFIG,
      useValue: { disabledInteractive: true },
    },
    {
      provide: MAT_BUTTON_CONFIG,
      useValue: { defaultAppearance: "outlined" },
    },
  ],
};

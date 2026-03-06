require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const cookieParser = require("cookie-parser");
const config = require("./config");

// Rutas
const authRoutes = require("./routes/auth");
const appsRoutes = require("./routes/apps");
const launchRoutes = require("./routes/launch");

const app = express();

// ── Seguridad ────────────────────────────────────────────────────────────────
app.use(helmet());

// ── CORS — permite el frontend Angular ──────────────────────────────────────
app.use(
  cors({
    origin: ["http://localhost:4200", "http://localhost:4300"],
    credentials: true, // necesario para enviar/recibir cookies
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  }),
);

// ── Parsers ──────────────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// ── Health check ─────────────────────────────────────────────────────────────
app.get("/api/health", (req, res) => {
  res.json({
    status: "ok",
    simulationMode: config.simulation.enabled,
    rdcbServer: config.rdcb.server,
    timestamp: new Date().toISOString(),
  });
});

// ── API Routes ────────────────────────────────────────────────────────────────
app.use("/api/auth", authRoutes);
app.use("/api/apps", appsRoutes);
app.use("/api/launch", launchRoutes);

// ── 404 handler ──────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: "Ruta no encontrada" });
});

// ── Error handler global ─────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  console.error("[Global Error]", err);
  res.status(500).json({ error: "Error interno del servidor" });
});

// ── Iniciar servidor ─────────────────────────────────────────────────────────
app.listen(config.port, () => {
  console.log("");
  console.log("  ╔══════════════════════════════════════╗");
  console.log("  ║       RDWeb-Moderno  Backend         ║");
  console.log(`  ║   Servidor en puerto ${config.port}            ║`);
  console.log(
    `  ║   Modo: ${config.simulation.enabled ? "SIMULACIÓN 🟡         " : "PRODUCCIÓN 🟢         "}       ║`,
  );
  console.log(`  ║   RDCB: ${config.rdcb.server.padEnd(24)}    ║`);
  console.log("  ╚══════════════════════════════════════╝");
  console.log("");
  console.log(`  API Health: http://localhost:${config.port}/api/health`);
  console.log("");
});

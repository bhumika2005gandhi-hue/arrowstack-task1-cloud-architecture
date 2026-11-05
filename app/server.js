###############################################################################
# Sample Node.js Express app — Task 1 Cloud-Hosted Business API
# Demonstrates: health check, items CRUD against Postgres, structured logs.
###############################################################################
const express = require("express");
const { Pool } = require("pg");
const os = require("os");
const fs = require("fs");

const PORT = process.env.APP_PORT || 3000;
const HOST = process.env.DB_HOST;
const DB_NAME = process.env.DB_NAME || "appdb";
const DB_USER = process.env.DB_USER;
const DB_PASS = process.env.DB_PASSWORD;

const app = express();
app.use(express.json());

// --- Structured logging ---
function log(level, msg, extra = {}) {
  const line = JSON.stringify({ ts: new Date().toISOString(), level, msg, host: os.hostname(), ...extra });
  console.log(line);
  try { fs.appendFileSync("/opt/app/app.log", line + "\n"); } catch (e) { /* ignore */ }
}

// --- Postgres pool ---
const pool = new Pool({
  host: HOST,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASS,
  port: 5432,
  connectionTimeoutMillis: 5000,
  max: 10,
});

// --- Bootstrap schema on startup ---
async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS items (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      price NUMERIC(10,2) DEFAULT 0,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
  `);
  log("info", "schema initialized");
}

// --- Routes ---
app.get("/health", async (req, res) => {
  try {
    const r = await pool.query("SELECT 1");
    res.json({ status: "ok", host: os.hostname(), db: "up", ts: new Date().toISOString() });
  } catch (e) {
    log("error", "health check db failure", { err: e.message });
    res.status(503).json({ status: "degraded", db: "down", err: e.message });
  }
});

app.get("/", (req, res) => res.json({ service: "arrowstack-t1-app", version: "1.0.0", host: os.hostname() }));

app.get("/items", async (req, res) => {
  const r = await pool.query("SELECT * FROM items ORDER BY id DESC LIMIT 100");
  res.json(r.rows);
});

app.post("/items", async (req, res) => {
  const { name, description, price } = req.body || {};
  if (!name) return res.status(400).json({ error: "name required" });
  const r = await pool.query(
    "INSERT INTO items (name, description, price) VALUES ($1,$2,$3) RETURNING *",
    [name, description || null, price || 0]
  );
  log("info", "item created", { id: r.rows[0].id });
  res.status(201).json(r.rows[0]);
});

app.get("/items/:id", async (req, res) => {
  const r = await pool.query("SELECT * FROM items WHERE id = $1", [req.params.id]);
  if (r.rows.length === 0) return res.status(404).json({ error: "not found" });
  res.json(r.rows[0]);
});

// --- Centralised error handler ---
app.use((err, req, res, next) => {
  log("error", "unhandled", { path: req.path, err: err.message });
  res.status(500).json({ error: "internal_error" });
});

init().then(() => {
  app.listen(PORT, () => log("info", "app listening", { port: PORT }));
}).catch((e) => {
  log("error", "init failed, exiting", { err: e.message });
  process.exit(1);
});

module.exports = app;

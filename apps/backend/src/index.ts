// src/index.ts
import express from "express";
import cors from "cors";
import * as data from "./data";

const app = express();
const PORT = process.env.PORT ? Number(process.env.PORT) : 4000;
const FRONTEND_ORIGIN = process.env.FRONTEND_ORIGIN || "http://localhost:3000";

app.use(cors({ origin: FRONTEND_ORIGIN }));
app.use(express.json());

app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

app.get("/api/health", (_req, res) => res.json({ status: "ok" }));

app.get("/api/kpis", (_req, res) => res.json(data.dashboardKpis));

app.get("/api/raw-materials", (_req, res) => res.json(data.rawMaterials));
app.post("/api/raw-materials", (req, res) => {
  const item = { id: `rm-${data.rawMaterials.length + 1}`, ...req.body };
  data.rawMaterials.push(item);
  res.status(201).json(item);
});
app.get("/api/raw-materials/:id", (req, res) => {
  const item = data.rawMaterials.find((m) => m.id === req.params.id);
  if (!item) return res.status(404).json({ error: "Not found" });
  res.json(item);
});
app.post("/api/raw-materials/:id/receipts", (req, res) => {
  res.status(201).json({ received: true, rawMaterialId: req.params.id, ...req.body });
});

app.get("/api/packaging-materials", (_req, res) => res.json(data.packagingMaterials));
app.post("/api/packaging-materials/:id/restock", (req, res) => {
  res.status(201).json({ restocked: true, materialId: req.params.id, ...req.body });
});

app.get("/api/batches", (_req, res) => res.json(data.productionBatches));
app.get("/api/batches/:id", (req, res) => {
  const item = data.productionBatches.find((b) => b.id === req.params.id);
  if (!item) return res.status(404).json({ error: "Not found" });
  res.json(item);
});
app.post("/api/batches", (req, res) => {
  const item = { id: `batch-${data.productionBatches.length + 1}`, status: "in_progress", ...req.body };
  data.productionBatches.push(item);
  res.status(201).json(item);
});
app.post("/api/batches/:id/overhead", (req, res) => {
  res.status(200).json({ allocated: true, batchId: req.params.id, ...req.body });
});

app.get("/api/finished-cartons", (_req, res) => res.json(data.finishedCartons));
app.post("/api/finished-cartons/packing-run", (req, res) => {
  res.status(201).json({ packed: true, ...req.body });
});

app.get("/api/customers", (_req, res) => res.json(data.customers));
app.post("/api/customers", (req, res) => {
  const item = { id: `cust-${data.customers.length + 1}`, currentBalance: 0, ...req.body };
  data.customers.push(item);
  res.status(201).json(item);
});
app.get("/api/customers/:id", (req, res) => {
  const item = data.customers.find((c) => c.id === req.params.id);
  if (!item) return res.status(404).json({ error: "Not found" });
  res.json(item);
});
app.get("/api/customers/:id/item-prices", (req, res) => {
  const rows = data.customerItemPrices.filter((p) => p.customerId === req.params.id);
  res.json(rows);
});

app.get("/api/invoices", (_req, res) => res.json(data.invoices));
app.get("/api/invoices/:id", (req, res) => {
  const item = data.invoices.find((i) => i.id === req.params.id);
  if (!item) return res.status(404).json({ error: "Not found" });
  res.json(item);
});
app.post("/api/invoices", (req, res) => {
  const item = { id: `inv-${1000 + data.invoices.length + 1}`, status: "unpaid", ...req.body };
  data.invoices.push(item);
  res.status(201).json(item);
});
app.get("/api/invoices/:id/pdf", (req, res) => {
  res.status(200).json({ message: "PDF generation not implemented yet", invoiceId: req.params.id });
});

app.get("/api/payments", (_req, res) => res.json(data.payments));
app.post("/api/payments", (req, res) => {
  const item = { id: `pay-${data.payments.length + 1}`, ...req.body };
  data.payments.push(item);
  res.status(201).json(item);
});

app.get("/api/reports/inventory", (_req, res) => {
  res.json({ rawMaterials: data.rawMaterials, packagingMaterials: data.packagingMaterials });
});
app.get("/api/reports/pnl", (_req, res) => {
  res.json({ batches: data.productionBatches, invoices: data.invoices });
});

app.get("/api/settings", (_req, res) => res.json(data.settings));
app.patch("/api/settings", (req, res) => {
  data.settings = { ...data.settings, ...req.body };
  res.json(data.settings);
});

app.listen(PORT, () => {
  console.log(`GhaniFoods backend running at http://localhost:${PORT}`);
});
# monorepo-setup.ps1
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods
# Usage: .\monorepo-setup.ps1

$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot

function Write-FileB64 {
    param([string]$RelativePath, [string]$Content)
    $full = Join-Path $Root $RelativePath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    [System.IO.File]::WriteAllBytes($full, $bytes)
    Write-Host "  + $RelativePath" -ForegroundColor DarkGray
}

Write-Host "=== GhaniFoods Monorepo Setup ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------
# 1. Create apps/frontend and apps/backend
# ---------------------------------------------------------------------
Write-Host "`n[1/6] Creating apps/frontend and apps/backend folders..." -ForegroundColor Yellow
$frontendDir = Join-Path $Root "apps\frontend"
$backendDir  = Join-Path $Root "apps\backend"
New-Item -ItemType Directory -Path $frontendDir -Force | Out-Null
New-Item -ItemType Directory -Path $backendDir -Force | Out-Null
Write-Host "  Done." -ForegroundColor Green

# ---------------------------------------------------------------------
# 2. Move existing frontend files/folders into apps/frontend
# ---------------------------------------------------------------------
Write-Host "`n[2/6] Moving existing frontend code into apps/frontend..." -ForegroundColor Yellow

$ExcludeFromMove = @(
    "apps",
    ".git",
    "node_modules",
    "export-code.ps1",
    "setup-ghanifoods-frontend.ps1",
    "monorepo-setup.ps1",
    "code-export.txt"
)

Get-ChildItem -Path $Root -Force | Where-Object {
    $ExcludeFromMove -notcontains $_.Name
} | ForEach-Object {
    Write-Host "  moving $($_.Name) -> apps\frontend\$($_.Name)" -ForegroundColor DarkGray
    Move-Item -Path $_.FullName -Destination (Join-Path $frontendDir $_.Name) -Force
}

$staleModules = Join-Path $Root "node_modules"
if (Test-Path $staleModules) {
    Write-Host "  removing stale root node_modules..." -ForegroundColor DarkGray
    Remove-Item -Path $staleModules -Recurse -Force
}
Write-Host "  Frontend moved." -ForegroundColor Green

# ---------------------------------------------------------------------
# 3. Ensure apps/frontend/package.json has proper scripts + name
# ---------------------------------------------------------------------
Write-Host "`n[3/6] Patching apps/frontend/package.json (scripts)..." -ForegroundColor Yellow

$frontendPkgPath = Join-Path $frontendDir "package.json"
if (Test-Path $frontendPkgPath) {
    $pkg = Get-Content $frontendPkgPath -Raw | ConvertFrom-Json

    if (-not $pkg.name) { $pkg | Add-Member -NotePropertyName name -NotePropertyValue "ghanifoods-frontend" -Force }
    else { $pkg.name = "ghanifoods-frontend" }

    if (-not $pkg.private) { $pkg | Add-Member -NotePropertyName private -NotePropertyValue $true -Force }

    if (-not $pkg.scripts) {
        $pkg | Add-Member -NotePropertyName scripts -NotePropertyValue ([PSCustomObject]@{}) -Force
    }
    if (-not $pkg.scripts.dev)   { $pkg.scripts | Add-Member -NotePropertyName dev   -NotePropertyValue "next dev --turbopack" -Force }
    if (-not $pkg.scripts.build) { $pkg.scripts | Add-Member -NotePropertyName build -NotePropertyValue "next build --turbopack" -Force }
    if (-not $pkg.scripts.start) { $pkg.scripts | Add-Member -NotePropertyName start -NotePropertyValue "next start" -Force }
    if (-not $pkg.scripts.lint)  { $pkg.scripts | Add-Member -NotePropertyName lint  -NotePropertyValue "next lint" -Force }

    $pkg | ConvertTo-Json -Depth 20 | Set-Content -Path $frontendPkgPath -Encoding UTF8
    Write-Host "  Patched." -ForegroundColor Green
} else {
    Write-Host "  WARNING: apps/frontend/package.json not found - skipping patch." -ForegroundColor Red
}

# ---------------------------------------------------------------------
# 4. Scaffold backend (Express + TypeScript, mock data, CORS enabled)
# ---------------------------------------------------------------------
Write-Host "`n[4/6] Scaffolding apps/backend..." -ForegroundColor Yellow

$backendPkg = @'
{
  "name": "ghanifoods-backend",
  "version": "0.1.0",
  "private": true,
  "main": "dist/index.js",
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.19.2"
  },
  "devDependencies": {
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/node": "^22.7.5",
    "tsx": "^4.19.2",
    "typescript": "^5.6.3"
  }
}
'@
Write-FileB64 "apps\backend\package.json" $backendPkg

$backendTsconfig = @'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "Node",
    "lib": ["ES2022"],
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src"]
}
'@
Write-FileB64 "apps\backend\tsconfig.json" $backendTsconfig

$backendGitignore = @'
node_modules
dist
.env
'@
Write-FileB64 "apps\backend\.gitignore" $backendGitignore

$backendEnvExample = @'
PORT=4000
FRONTEND_ORIGIN=http://localhost:3000
'@
Write-FileB64 "apps\backend\.env.example" $backendEnvExample

$backendData = @'
// src/data.ts
// In-memory mock data for local/dev use - mirrors apps/frontend/lib/mock-data/*
// Replace with real DB (Prisma/Postgres etc.) later without changing route shapes.

export type RawMaterial = {
  id: string; name: string; unit: string;
  quantityInStock: number; avgUnitCost: number; lowStockThreshold: number;
};
export let rawMaterials: RawMaterial[] = [
  { id: "rm-1", name: "Atta (Flour)", unit: "kg", quantityInStock: 420, avgUnitCost: 145.5, lowStockThreshold: 100 },
  { id: "rm-2", name: "Ghee", unit: "kg", quantityInStock: 65, avgUnitCost: 780, lowStockThreshold: 80 },
  { id: "rm-3", name: "Salt", unit: "kg", quantityInStock: 210, avgUnitCost: 28, lowStockThreshold: 50 },
  { id: "rm-4", name: "Spice Mix", unit: "kg", quantityInStock: 34, avgUnitCost: 620, lowStockThreshold: 40 },
];

export type PackagingMaterial = {
  id: string; name: string; unitCost: number; stockQty: number; lowStockThreshold: number;
};
export let packagingMaterials: PackagingMaterial[] = [
  { id: "pm-1", name: "Carton Box (Large)", unitCost: 45, stockQty: 320, lowStockThreshold: 100 },
  { id: "pm-2", name: "Shopper Bag", unitCost: 3.5, stockQty: 2400, lowStockThreshold: 500 },
  { id: "pm-3", name: "Dabbe (Tin)", unitCost: 22, stockQty: 150, lowStockThreshold: 60 },
];

export type ProductionBatch = {
  id: string; batchDate: string; outputYieldKg: number; wastageKg: number;
  leftoverQtyKg: number; bulkCostPerKg: number; status: "in_progress" | "completed";
};
export let productionBatches: ProductionBatch[] = [
  { id: "batch-1", batchDate: "2026-08-10", outputYieldKg: 500, wastageKg: 8, leftoverQtyKg: 40, bulkCostPerKg: 210.75, status: "completed" },
  { id: "batch-2", batchDate: "2026-08-13", outputYieldKg: 480, wastageKg: 5, leftoverQtyKg: 480, bulkCostPerKg: 205.3, status: "completed" },
  { id: "batch-3", batchDate: "2026-08-16", outputYieldKg: 300, wastageKg: 0, leftoverQtyKg: 0, bulkCostPerKg: 0, status: "in_progress" },
];

export type FinishedCarton = {
  id: string; name: string; sourceBatchId: string;
  packetsPerCarton: number; costPerCarton: number; stockQty: number;
};
export let finishedCartons: FinishedCarton[] = [
  { id: "fc-1", name: "Nimko Carton - 24pk", sourceBatchId: "batch-1", packetsPerCarton: 24, costPerCarton: 610, stockQty: 85 },
  { id: "fc-2", name: "Nimko Carton - 48pk", sourceBatchId: "batch-2", packetsPerCarton: 48, costPerCarton: 1150, stockQty: 42 },
];

export type Customer = { id: string; name: string; phone: string; currentBalance: number; };
export let customers: Customer[] = [
  { id: "cust-1", name: "Al-Madina General Store", phone: "0300-1234567", currentBalance: 12500 },
  { id: "cust-2", name: "Bilal Traders", phone: "0333-9988776", currentBalance: -2000 },
  { id: "cust-3", name: "Rehman Wholesale", phone: "0345-1122334", currentBalance: 0 },
];

export type Invoice = {
  id: string; customerId: string; customerName: string;
  invoiceDate: string; totalAmount: number; status: "unpaid" | "partial" | "paid";
};
export let invoices: Invoice[] = [
  { id: "inv-1001", customerId: "cust-1", customerName: "Al-Madina General Store", invoiceDate: "2026-08-15", totalAmount: 18300, status: "partial" },
  { id: "inv-1002", customerId: "cust-2", customerName: "Bilal Traders", invoiceDate: "2026-08-14", totalAmount: 9200, status: "paid" },
  { id: "inv-1003", customerId: "cust-3", customerName: "Rehman Wholesale", invoiceDate: "2026-08-12", totalAmount: 4600, status: "unpaid" },
];

export type Payment = {
  id: string; customerId: string; customerName: string;
  amount: number; note: string; paidAt: string;
};
export let payments: Payment[] = [
  { id: "pay-1", customerId: "cust-2", customerName: "Bilal Traders", amount: 9200, note: "Full settlement inv-1002", paidAt: "2026-08-15" },
  { id: "pay-2", customerId: "cust-1", customerName: "Al-Madina General Store", amount: 5800, note: "Partial payment", paidAt: "2026-08-16" },
];

export type CustomerItemPrice = { customerId: string; itemId: string; lastSoldPrice: number; };
export let customerItemPrices: CustomerItemPrice[] = [
  { customerId: "cust-1", itemId: "fc-1", lastSoldPrice: 640 },
  { customerId: "cust-2", itemId: "fc-2", lastSoldPrice: 1180 },
];

export const dashboardKpis = {
  totalRawMaterialValue: 128450,
  batchesThisMonth: 6,
  finishedCartonsReady: 127,
  totalReceivables: 15900,
};

export let settings = {
  businessName: "GhaniFoods",
  address: "Mansehra, Khyber Pakhtunkhwa, Pakistan",
  invoiceFooterText: "Thank you for your business!",
  defaultProfitMarginPercent: 20,
  lowStockThresholdDefault: 50,
};
'@
Write-FileB64 "apps\backend\src\data.ts" $backendData

$backendIndex = @'
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
'@
Write-FileB64 "apps\backend\src\index.ts" $backendIndex

Write-Host "  Backend scaffolded." -ForegroundColor Green

# ---------------------------------------------------------------------
# 5. Root package.json (npm workspaces + concurrently)
# ---------------------------------------------------------------------
Write-Host "`n[5/6] Writing root package.json and README..." -ForegroundColor Yellow

$rootPkg = @'
{
  "name": "ghanifoods-monorepo",
  "version": "0.1.0",
  "private": true,
  "workspaces": [
    "apps/*"
  ],
  "scripts": {
    "dev": "concurrently -k -n BACKEND,FRONTEND -c blue,green \"npm run dev --workspace=apps/backend\" \"npm run dev --workspace=apps/frontend\"",
    "dev:frontend": "npm run dev --workspace=apps/frontend",
    "dev:backend": "npm run dev --workspace=apps/backend",
    "build": "npm run build --workspace=apps/backend && npm run build --workspace=apps/frontend",
    "build:frontend": "npm run build --workspace=apps/frontend",
    "build:backend": "npm run build --workspace=apps/backend",
    "start:backend": "npm run start --workspace=apps/backend",
    "start:frontend": "npm run start --workspace=apps/frontend"
  },
  "devDependencies": {
    "concurrently": "^9.0.1"
  }
}
'@
Write-FileB64 "package.json" $rootPkg

$rootGitignore = @'
node_modules
.next
dist
.env
*.log
'@
Write-FileB64 ".gitignore" $rootGitignore

$readmeLines = @(
    "# GhaniFoods Monorepo",
    "",
    "apps/frontend = Next.js 15 (App Router) + Ant Design, currently running on mock data.",
    "apps/backend  = Express + TypeScript API, currently serving mock/in-memory data.",
    "",
    "## Run both together",
    "  npm install",
    "  npm run dev",
    "",
    "Frontend: http://localhost:3000",
    "Backend:  http://localhost:4000",
    "",
    "## Run separately",
    "  npm run dev:frontend   (just Next.js)",
    "  npm run dev:backend    (just Express API)",
    "",
    "## Build",
    "  npm run build"
)
$rootReadme = $readmeLines -join "`r`n"
Write-FileB64 "README.md" $rootReadme

Write-Host "  Root workspace files written." -ForegroundColor Green

# ---------------------------------------------------------------------
# 6. Install everything from root
# ---------------------------------------------------------------------
Write-Host "`n[6/6] Installing dependencies (root + workspaces)..." -ForegroundColor Yellow
Push-Location $Root
npm install
Pop-Location
Write-Host "  Installed." -ForegroundColor Green

Write-Host "`n=== Monorepo setup complete ===" -ForegroundColor Cyan
Write-Host "Structure:" -ForegroundColor White
Write-Host "  GhaniFoods\"
Write-Host "  |-- apps\frontend  (Next.js, moved as-is)"
Write-Host "  |-- apps\backend   (Express + TS, mock data)"
Write-Host "  `-- package.json   (workspaces root)"
Write-Host ""
Write-Host "Run both together:  npm run dev" -ForegroundColor Green
Write-Host "Frontend only:      npm run dev:frontend" -ForegroundColor Gray
Write-Host "Backend only:       npm run dev:backend" -ForegroundColor Gray
Write-Host "Frontend URL:       http://localhost:3000" -ForegroundColor Gray
Write-Host "Backend URL:        http://localhost:4000" -ForegroundColor Gray
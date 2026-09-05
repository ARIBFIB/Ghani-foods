# GhaniFoods — Nimco Production & Distribution Management System

A production, inventory, sales, and finance management system built for **Ghani Foods (Nimco)**, a food manufacturing business. It covers the full flow from raw material purchasing through production, packaging, invoicing, customer/supplier ledgers, and financial reporting.

**Live app:** [ghani-foods.vercel.app/login](https://ghani-foods.vercel.app/login)

> ⚠️ **Security note:** older diagnostic scripts in this repo (`.diag-tmp/`) contained hardcoded Supabase database credentials. If this repo has ever been pushed publicly with those files, rotate the database password immediately and keep `.diag-tmp/` out of version control (see [Security](#security) below).

---

## Overview

GhaniFoods is a monorepo with two applications:

- **`apps/frontend`** — Next.js 15 (App Router) dashboard used by staff to manage the entire business
- **`apps/backend`** — a thin Express/TypeScript service, plus the real business logic implemented as **Supabase Edge Functions** (Deno/TypeScript) that talk to a Postgres database via Supabase

Most day-to-day reads go straight from the frontend to Supabase (`select` queries); all writes that touch money, stock, or ledgers go through **Edge Functions**, which validate input and call Postgres RPC functions (`fn_*`) so business rules stay enforced in the database, not scattered across the UI.

## Core modules

| Module | What it does |
|---|---|
| **Raw Materials** | Master data, stock levels, average cost, low-stock thresholds, purchase history |
| **Suppliers** | Supplier master, ledger (payable/receivable), payment history |
| **Purchase Orders & Receipts** | Create POs, receive stock against a PO, auto-update raw material stock and average cost |
| **Packaging (Wrappers, Boxes, Cartons)** | Packaging material master, carton configurations, carton production runs |
| **Production Batches** | Record production runs, output yield, wastage, leftover tracking, batch costing |
| **Finished Cartons** | Finished goods inventory ready for sale |
| **Customers** | Customer master, per-item pricing, ledger, invoice history |
| **Invoices** | Create/manage sales invoices, PDF generation, price lookups |
| **Payments** | Record customer payments and supplier payments |
| **Credit / Debit Notes & Contra Vouchers** | Adjustments and internal fund transfers between cash/bank accounts |
| **Monthly Expenses & Overhead Allocation** | Track recurring expenses and allocate overhead into production cost |
| **Reports** | Inventory, production, P&L, and finished-carton availability reports |
| **Dashboard** | KPI summary across the business |
| **Data Export / Delete** | Bulk data export and a guarded "danger zone" for data deletion |

## Tech stack

**Frontend** (`apps/frontend`)
- Next.js 15 (App Router, Turbopack) · React 19 · TypeScript
- Tailwind CSS 4
- Supabase (`@supabase/ssr`, `@supabase/supabase-js`) for auth + data access
- TanStack Query (server state) · TanStack Table · Zustand (client state)
- React Hook Form + Zod for form validation
- Recharts (dashboard/report charts) · jsPDF (invoice/document PDFs)
- Radix UI primitives, Framer Motion, Lottie, Sonner (toasts), Carbon icons, Lucide icons

**Backend** (`apps/backend`)
- Express + TypeScript (lightweight local API/dev server)
- Supabase Edge Functions (Deno) — one function per business operation, under `apps/backend/supabase/functions/*`
- PostgreSQL (via Supabase), with business logic centralized in `fn_*` RPC functions

**Infra**
- Vercel — frontend hosting/deployment
- Supabase — Postgres database, Auth, Edge Functions

## Project structure

```
GhaniFoods/
├── apps/
│   ├── frontend/                  # Next.js 15 app (the dashboard UI)
│   │   ├── app/
│   │   │   ├── (auth)/login/      # Login page
│   │   │   └── (dashboard)/       # All authenticated pages — one folder per module
│   │   │       (raw-materials, suppliers, purchase-orders, packaging, batches,
│   │   │        finished-cartons, customers, invoices, payments,
│   │   │        monthly-expenses, reports, settings, receipts …)
│   │   ├── components/ui/         # Shared UI components & feature dialogs
│   │   ├── lib/                   # Supabase clients, API helpers, schemas, store, constants
│   │   └── middleware.ts          # Supabase session middleware (route protection)
│   │
│   └── backend/
│       ├── src/                   # Express dev server + in-memory mock data
│       └── supabase/functions/    # One Edge Function per operation (business logic)
│
├── supabase/                       # Supabase project linkage
├── deploy-supabase-function.ps1    # PowerShell script to deploy edge functions
├── export-code.ps1 / code-export.ps1  # Scripts used to export the codebase as JSON/zip
└── package.json                    # npm workspaces root (apps/*)
```

## Getting started

### Prerequisites
- Node.js 20+
- npm
- A Supabase project (Postgres + Edge Functions) with the required schema and `fn_*` functions already migrated

### Setup

```bash
# install all workspace dependencies
npm install

# set up environment variables
# apps/frontend/.env.local
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### Run locally

```bash
# run both frontend and backend together
npm run dev

# or individually
npm run dev:frontend
npm run dev:backend
```

Frontend runs on Next.js's default dev port; the Express backend is a separate local dev service used for early-stage/mock endpoints (`apps/backend/src/data.ts` holds in-memory mock data for pre-database development).

### Build

```bash
npm run build            # builds backend then frontend
npm run build:frontend
npm run build:backend
```

### Deploy Supabase Edge Functions

```powershell
./deploy-supabase-function.ps1
```

## Authentication

Auth is handled entirely through Supabase:
- `apps/frontend/lib/supabase/client.ts` — browser client
- `apps/frontend/lib/supabase/server.ts` — server client
- `apps/frontend/lib/supabase/middleware.ts` + `middleware.ts` — refreshes the session on every request and protects dashboard routes

## Security

- **Never commit database credentials, service-role keys, or connection strings.** Diagnostic/one-off scripts (like the former `.diag-tmp/*.js` files) should read credentials from environment variables, not hardcode them.
- Add `.diag-tmp/`, `.env`, `.env.local`, and `supabase/.temp/` to `.gitignore`.
- If credentials were ever committed, treat them as compromised: rotate the Supabase database password and any exposed API keys immediately, then purge them from git history.
- All business-logic writes go through validated Edge Functions rather than direct table writes from the client, keeping RPC/database access behind server-side validation.

## Screenshots

**Login**
<img width="959" height="433" alt="Login page" src="https://github.com/user-attachments/assets/0512977f-4a52-4f24-8139-7c09d944e115" />

**Dashboard**
<img width="952" height="436" alt="Dashboard" src="https://github.com/user-attachments/assets/99209fbf-c200-4cd3-b029-eeb498438699" />

### Raw Materials

<img width="657" height="176" alt="Raw material details" src="https://github.com/user-attachments/assets/52e14e9a-6e14-480f-a41a-5d14515af0ee" />

### Suppliers

<img width="947" height="430" alt="Supplier details" src="https://github.com/user-attachments/assets/cba09b1b-e022-4836-9e62-1e4bb7ab2d57" />

**Record supplier payment**
<img width="950" height="430" alt="Record supplier payment" src="https://github.com/user-attachments/assets/62a65596-84d7-4eae-9e10-9dc1a724523b" />

**Debit note (purchase return)**
<img width="949" height="433" alt="Debit note" src="https://github.com/user-attachments/assets/0ceab5d2-4322-4ae9-be12-5ea19d2f3d66" />

### Packaging

**Packaging materials**
<img width="959" height="434" alt="Packaging materials" src="https://github.com/user-attachments/assets/73d859a4-e2dc-433f-bf2c-88e0eddfb7c7" />

**Produce packaging (e.g. 5rs wrapper)**
<img width="959" height="427" alt="Produce wrapper" src="https://github.com/user-attachments/assets/554cccf6-c893-42b0-a4c6-ca452bc7197e" />

**Boxes**
<img width="658" height="385" alt="Packaging boxes" src="https://github.com/user-attachments/assets/a0af37c9-025d-4337-ae98-b425834f68a8" />

**Define wrapper**
<img width="959" height="436" alt="Define wrapper" src="https://github.com/user-attachments/assets/6eec2a7a-5145-40e3-9865-9b7a80f35bee" />

**Carton configurations**
<img width="680" height="343" alt="Carton configurations" src="https://github.com/user-attachments/assets/0d00d647-c293-4fe9-96f9-0bffa81a45fc" />

**New carton configuration**
<img width="959" height="440" alt="New carton configuration 1" src="https://github.com/user-attachments/assets/b302bc4c-106e-4b6c-9333-a9c0f7e88325" />
<img width="959" height="433" alt="New carton configuration 2" src="https://github.com/user-attachments/assets/dd2e0ae4-4ab3-41f5-836c-e8b49b77ab97" />

### Purchase Receipts & Orders

**Receipts list**
<img width="950" height="431" alt="Receipts list" src="https://github.com/user-attachments/assets/8eaea66b-39aa-449e-8f44-6a337f146be4" />
<img width="662" height="298" alt="Receipt detail" src="https://github.com/user-attachments/assets/e6127f36-7765-4ec9-a9f1-11832043e17e" />

**New purchase receipt**
<img width="946" height="428" alt="New purchase receipt" src="https://github.com/user-attachments/assets/5d8edf9c-a65d-412c-b3d2-756c41e2b479" />
<img width="954" height="436" alt="New purchase receipt 2" src="https://github.com/user-attachments/assets/8bfbf505-7678-497f-a421-212d309b90f4" />

**Purchase orders**
<img width="677" height="348" alt="Purchase orders" src="https://github.com/user-attachments/assets/c209bf45-27a7-465c-9dba-d7a55fc89f8a" />
<img width="629" height="221" alt="Purchase orders detail" src="https://github.com/user-attachments/assets/7293a979-e1e2-4a72-91bf-d86739a1df88" />

**New purchase order**
<img width="947" height="434" alt="New purchase order" src="https://github.com/user-attachments/assets/023cd3f0-508a-4d44-b2d3-1e18040d4897" />

### Production Batches

<img width="959" height="425" alt="Production batches" src="https://github.com/user-attachments/assets/955ffbc6-f999-447c-8f99-ae14f86d93ff" />
<img width="727" height="394" alt="Production batches detail" src="https://github.com/user-attachments/assets/6a315084-92e9-480a-9c6a-01d8d53a821b" />

**New production batch**
<img width="944" height="429" alt="New production batch" src="https://github.com/user-attachments/assets/4401d6b7-e3f1-4be5-b00b-2e2b68db699c" />

**Use leftover from previous batch first**
<img width="647" height="170" alt="Use leftover from previous batch" src="https://github.com/user-attachments/assets/a3a8d55d-29fc-40dd-b8e4-c4996c9fef34" />

### Monthly Expenses

Accumulative shared costs (electricity, gas, rent, etc.) for a month, split across every batch produced that month.
<img width="654" height="384" alt="Monthly expenses" src="https://github.com/user-attachments/assets/618c6e56-b947-495e-af63-ec1e42ae2d89" />

### Finished Cartons

**Ready for sale**
<img width="959" height="420" alt="Finished cartons ready for sale" src="https://github.com/user-attachments/assets/aa9fa85f-4028-4c95-97e8-2e8646732c44" />

**Unpacked / leftover**
<img width="686" height="323" alt="Finished cartons unpacked/leftover" src="https://github.com/user-attachments/assets/a8692a0d-7318-4891-8744-0522c38ab0a2" />

**New packing run — step 1 of 3**
<img width="497" height="333" alt="New packing run step 1" src="https://github.com/user-attachments/assets/ecf9ef79-8e66-4a8f-aee4-dee384cd24ea" />

**New packing run — step 2 of 3**
<img width="646" height="424" alt="New packing run step 2" src="https://github.com/user-attachments/assets/75aac9ee-7512-4eeb-9b0f-8f607e9f785a" />

**New packing run — step 3 of 3**
<img width="941" height="430" alt="New packing run step 3" src="https://github.com/user-attachments/assets/a2ce662e-115e-447f-9944-6070d8c9a032" />

### Customers

<img width="959" height="437" alt="Customers list" src="https://github.com/user-attachments/assets/a3e40bef-fc1d-480f-842f-5b2f11709fc1" />
<img width="664" height="374" alt="Customer detail" src="https://github.com/user-attachments/assets/982d0434-7ed8-4cc7-8917-463ca0cd66a0" />

**Record customer payment**
<img width="941" height="426" alt="Customer record payment" src="https://github.com/user-attachments/assets/30b57335-ee68-4ac1-b19b-e1006c73d40b" />

### Invoices

<img width="959" height="434" alt="Invoices list" src="https://github.com/user-attachments/assets/ebc0c0f0-ae62-4b52-9cd3-2e837618782d" />

**Invoice detail (INV-1004)**
<img width="678" height="375" alt="Invoice detail" src="https://github.com/user-attachments/assets/e4f16d0a-630a-4a39-b398-8ebcddd3bf85" />

**Print receipt**
<img width="957" height="432" alt="Print receipt" src="https://github.com/user-attachments/assets/913b2378-a254-48f8-97e3-ae5daf94c087" />

**Print PDF**
<img width="957" height="468" alt="Print PDF" src="https://github.com/user-attachments/assets/f3647b3c-3940-4980-a0bb-bba5655dd748" />

**Record payment**
<img width="954" height="426" alt="Record payment" src="https://github.com/user-attachments/assets/f0edf873-0336-4fa0-9690-2312bf5f0ad6" />

**Credit note (sales return)**
<img width="959" height="433" alt="Credit note" src="https://github.com/user-attachments/assets/6a798b93-a48c-4b33-9db2-63ca6e1afd8d" />

**New invoice**
<img width="656" height="377" alt="New invoice 1" src="https://github.com/user-attachments/assets/c8eae585-7aa2-48a2-b435-c7b104f0840f" />
<img width="609" height="239" alt="New invoice 2" src="https://github.com/user-attachments/assets/6a3b40a0-8f98-4140-8ada-0377f00ba1e5" />

### Payments

<img width="958" height="433" alt="Payments" src="https://github.com/user-attachments/assets/21f50f81-c480-404e-bf0c-9fe33208329e" />

**Contra transfer (bank ↔ cash)**
<img width="959" height="434" alt="Contra transfer" src="https://github.com/user-attachments/assets/25913a9a-4bdc-42f4-acc1-639ad426ee92" />

### Reports & Analytics

<img width="947" height="429" alt="Reports and analytics 1" src="https://github.com/user-attachments/assets/c6197095-8ea6-4dcf-884d-04fb56fe9c8f" />
<img width="669" height="320" alt="Reports and analytics 2" src="https://github.com/user-attachments/assets/73e16199-f13f-4604-bcdf-f056b8ea093a" />

### Settings

<img width="945" height="434" alt="Settings" src="https://github.com/user-attachments/assets/e44af486-4632-426d-a34e-a081d61c3e2d" />

**Export data**
<img width="583" height="356" alt="Export data" src="https://github.com/user-attachments/assets/07a2c0a7-ec57-414b-9066-dd0c02087aa7" />

**Dark theme**
<img width="948" height="435" alt="Dark theme" src="https://github.com/user-attachments/assets/661806c2-028f-437a-8b27-83a1a72ce2f3" />

## Roadmap / known work

The project has an active remediation backlog covering: fixing failing purchase-receipt and supplier-payment operations, sidebar and dropdown UX, duplicate-prevention on raw materials, unit-conversion consistency across production dialogs, treating cartons as consumable stock, supplier/customer ledger accuracy, cash/bank account consolidation, invoice/PO print support, and an expanded reports section.

## License

Proprietary — internal system built for Ghani Foods (Nimco). Not licensed for external reuse.

const { Client } = require("pg");
const fs = require("fs");

const client = new Client({
  host: "aws-0-ap-southeast-1.pooler.supabase.com",
  port: 6543,
  database: "postgres",
  user: "postgres.hbvcdxhdkbksknasdqst",
  password: "S0ep2CxuMkk0FgEH",
  ssl: { rejectUnauthorized: false },
});

const outLines = [];
function log(title, rows) {
  outLines.push(`\n===== ${title} =====\n`);
  if (!rows || rows.length === 0) {
    outLines.push("(no rows)");
  } else {
    outLines.push(JSON.stringify(rows, null, 2));
  }
}

async function run() {
  await client.connect();

  let res;

  res = await client.query(`
    SELECT p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS arguments,
           pg_get_functiondef(p.oid) AS full_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_create_purchase_receipt_from_po';
  `);
  log("fn_create_purchase_receipt_from_po - existence + signature", res.rows);

  res = await client.query(`
    SELECT p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS arguments
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_create_purchase_receipt';
  `);
  log("fn_create_purchase_receipt (old, PO-less) - existence", res.rows);

  res = await client.query(`
    SELECT p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS arguments,
           pg_get_functiondef(p.oid) AS full_definition
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_record_supplier_payment';
  `);
  log("fn_record_supplier_payment - existence + signature", res.rows);

  res = await client.query(`
    SELECT p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS arguments
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname LIKE 'fn_%'
    ORDER BY p.proname;
  `);
  log("All fn_* functions currently in DB", res.rows);

  const tables = [
    "purchase_orders",
    "purchase_order_items",
    "purchase_receipts",
    "purchase_receipt_items",
    "raw_materials",
    "suppliers",
    "supplier_payments",
    "treasury_accounts",
    "cash_accounts",
    "bank_accounts",
    "stock_ledger",
    "stock_movements",
    "inventory_transactions",
  ];

  for (const t of tables) {
    res = await client.query(
      `SELECT column_name, data_type, is_nullable, column_default
       FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = $1
       ORDER BY ordinal_position;`,
      [t]
    );
    log(`Table columns: ${t}`, res.rows);
  }

  res = await client.query(`
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public' ORDER BY table_name;
  `);
  log("All tables in public schema", res.rows);

  await client.end();
  fs.writeFileSync(process.argv[2], outLines.join("\n"));
  console.log("DONE");
}

run().catch((err) => {
  fs.writeFileSync(process.argv[2], "CONNECTION/QUERY ERROR:\n" + (err.stack || err.message || String(err)));
  console.error("ERROR:", err.message);
  process.exit(1);
});

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
function log(title, content) {
  outLines.push(`\n===== ${title} =====\n`);
  outLines.push(typeof content === "string" ? content : JSON.stringify(content, null, 2));
}

async function run() {
  await client.connect();

  // 1. Drop ONLY the old 3-arg overload
  await client.query(`
    DROP FUNCTION IF EXISTS public.fn_create_purchase_receipt_from_po(uuid, date, jsonb);
  `);
  log("DROP old 3-arg overload", "Executed: DROP FUNCTION IF EXISTS public.fn_create_purchase_receipt_from_po(uuid, date, jsonb);");

  // 2. Verify only one overload remains
  const res = await client.query(`
    SELECT p.proname AS function_name,
           pg_get_function_identity_arguments(p.oid) AS arguments
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_create_purchase_receipt_from_po'
    ORDER BY arguments;
  `);
  log("Remaining fn_create_purchase_receipt_from_po overloads (should be exactly 1, the 4-arg version)", res.rows);

  await client.end();
  fs.writeFileSync(process.argv[2], outLines.join("\n"));
  console.log("DONE");
}

run().catch((err) => {
  fs.writeFileSync(process.argv[2], "ERROR:\n" + (err.stack || err.message || String(err)));
  console.error("ERROR:", err.message);
  process.exit(1);
});

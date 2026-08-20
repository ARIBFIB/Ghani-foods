// apps/backend/supabase/functions/data-export/index.ts
//
// Exports GhaniFoods business data as CSV, XLSX, PDF, or DOCX.
// Request body:
// {
//   modules: string[],              // keys from TABLE_MAP, or ["all"]
//   format: "csv" | "xlsx" | "pdf" | "docx",
//   dateRange?: { from?: string; to?: string }   // "YYYY-MM-DD", applied to date-bearing tables
// }
//
// Response: { downloadUrl: string, fileName: string }

import { createClient } from "npm:@supabase/supabase-js@2";
import ExcelJS from "npm:exceljs@4";
import { Document, Packer, Paragraph, HeadingLevel, Table, TableRow, TableCell, WidthType } from "npm:docx@9";
import { PDFDocument, StandardFonts, rgb } from "npm:pdf-lib@1";
import { corsHeaders } from "../_shared/cors.ts";

// ---------------------------------------------------------------------
// IMPORTANT: adjust these to match your real schema (see 0001_init_schema.sql)
// key = module name shown in the UI, value = { table, dateColumn? }
// ---------------------------------------------------------------------
const TABLE_MAP: Record<string, { table: string; dateColumn?: string }> = {
  rawMaterials: { table: "raw_materials" },
  suppliers: { table: "suppliers" },
  receipts: { table: "receipts", dateColumn: "purchase_date" },
  receiptLines: { table: "receipt_lines" },
  batches: { table: "batches", dateColumn: "created_at" },
  customers: { table: "customers" },
  invoices: { table: "invoices", dateColumn: "invoice_date" },
  invoiceLines: { table: "invoice_lines" },
  payments: { table: "payments", dateColumn: "payment_date" },
  wrappers: { table: "wrappers" },
  boxes: { table: "boxes" },
  cartonConfigurations: { table: "carton_configurations" },
  finishedCartons: { table: "finished_cartons" },
};

const PROJECT_NAME = "GhaniFoods";

function humanize(key: string) {
  return key.replace(/([A-Z])/g, " $1").replace(/^./, (c) => c.toUpperCase());
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const body = await req.json();
    let { modules, format, dateRange } = body as {
      modules: string[];
      format: "csv" | "xlsx" | "pdf" | "docx";
      dateRange?: { from?: string; to?: string };
    };

    if (!modules || modules.length === 0 || modules[0] === "all") {
      modules = Object.keys(TABLE_MAP);
    }
    modules = modules.filter((m) => TABLE_MAP[m]);

    if (modules.length === 0) {
      return new Response(JSON.stringify({ error: "No valid modules requested" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ---------------------------------------------------------------
    // 1. Fetch data for each module
    // ---------------------------------------------------------------
    const datasets: { key: string; label: string; rows: Record<string, unknown>[] }[] = [];

    for (const key of modules) {
      const { table, dateColumn } = TABLE_MAP[key];
      let query = supabase.from(table).select("*");

      if (dateColumn && dateRange?.from) query = query.gte(dateColumn, dateRange.from);
      if (dateColumn && dateRange?.to) query = query.lte(dateColumn, dateRange.to);

      const { data, error } = await query;
      if (error) throw new Error(`Failed to fetch ${table}: ${error.message}`);

      datasets.push({ key, label: humanize(key), rows: data ?? [] });
    }

    const generatedAt = new Date().toISOString();
    const rangeNote =
      dateRange?.from || dateRange?.to
        ? `Date range: ${dateRange?.from ?? "start"} to ${dateRange?.to ?? "today"}`
        : "Date range: all time";

    // ---------------------------------------------------------------
    // 2. Build the file
    // ---------------------------------------------------------------
    let fileBytes: Uint8Array;
    let ext: string;
    let contentType: string;

    if (format === "csv") {
      // If multiple modules, we zip-less concat with section headers (simplest, no extra dependency).
      const parts: string[] = [];
      for (const ds of datasets) {
        parts.push(`# ${ds.label}`);
        if (ds.rows.length === 0) {
          parts.push("(no data)");
        } else {
          const headers = Object.keys(ds.rows[0]);
          parts.push(headers.join(","));
          for (const row of ds.rows) {
            parts.push(
              headers
                .map((h) => {
                  const v = row[h];
                  const s = v === null || v === undefined ? "" : String(v);
                  return `"${s.replace(/"/g, '""')}"`;
                })
                .join(","),
            );
          }
        }
        parts.push("");
      }
      fileBytes = new TextEncoder().encode(parts.join("\n"));
      ext = "csv";
      contentType = "text/csv";
    } else if (format === "xlsx") {
      const workbook = new ExcelJS.Workbook();
      workbook.creator = PROJECT_NAME;
      workbook.created = new Date();

      for (const ds of datasets) {
        const sheet = workbook.addWorksheet(ds.label.slice(0, 31)); // Excel sheet name limit
        if (ds.rows.length > 0) {
          const headers = Object.keys(ds.rows[0]);
          sheet.addRow(headers).font = { bold: true };
          for (const row of ds.rows) sheet.addRow(headers.map((h) => row[h] ?? ""));
          sheet.columns.forEach((col) => (col.width = 18));
        } else {
          sheet.addRow(["(no data)"]);
        }
      }

      const buf = await workbook.xlsx.writeBuffer();
      fileBytes = new Uint8Array(buf as ArrayBuffer);
      ext = "xlsx";
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    } else if (format === "docx") {
      const children: Paragraph[] = [
        new Paragraph({ text: PROJECT_NAME, heading: HeadingLevel.TITLE }),
        new Paragraph({ text: "Data Export Report" }),
        new Paragraph({ text: `Generated: ${generatedAt}` }),
        new Paragraph({ text: rangeNote }),
        new Paragraph({ text: "" }),
      ];

      const content: (Paragraph | Table)[] = [...children];

      for (const ds of datasets) {
        content.push(new Paragraph({ text: ds.label, heading: HeadingLevel.HEADING_1 }));
        if (ds.rows.length === 0) {
          content.push(new Paragraph({ text: "(no data)" }));
          continue;
        }
        const headers = Object.keys(ds.rows[0]);
        const rows = [
          new TableRow({
            children: headers.map(
              (h) =>
                new TableCell({
                  width: { size: 100 / headers.length, type: WidthType.PERCENTAGE },
                  children: [new Paragraph({ text: h, heading: HeadingLevel.HEADING_5 })],
                }),
            ),
          }),
          ...ds.rows.map(
            (row) =>
              new TableRow({
                children: headers.map(
                  (h) =>
                    new TableCell({
                      width: { size: 100 / headers.length, type: WidthType.PERCENTAGE },
                      children: [new Paragraph({ text: String(row[h] ?? "") })],
                    }),
                ),
              }),
          ),
        ];
        content.push(new Table({ rows, width: { size: 100, type: WidthType.PERCENTAGE } }));
        content.push(new Paragraph({ text: "" }));
      }

      const doc = new Document({ sections: [{ children: content }] });
      const buf = await Packer.toBuffer(doc);
      fileBytes = new Uint8Array(buf);
      ext = "docx";
      contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    } else if (format === "pdf") {
      const pdfDoc = await PDFDocument.create();
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
      const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

      const pageWidth = 612;
      const pageHeight = 792;
      const margin = 40;
      const lineHeight = 14;

      let page = pdfDoc.addPage([pageWidth, pageHeight]);
      let y = pageHeight - margin;

      const ensureSpace = () => {
        if (y < margin + lineHeight) {
          page = pdfDoc.addPage([pageWidth, pageHeight]);
          y = pageHeight - margin;
        }
      };

      const drawText = (text: string, opts: { size?: number; bold?: boolean } = {}) => {
        ensureSpace();
        page.drawText(text, {
          x: margin,
          y,
          size: opts.size ?? 10,
          font: opts.bold ? boldFont : font,
          color: rgb(0, 0, 0),
        });
        y -= lineHeight;
      };

      drawText(PROJECT_NAME, { size: 20, bold: true });
      drawText("Data Export Report", { size: 12, bold: true });
      drawText(`Generated: ${generatedAt}`, { size: 9 });
      drawText(rangeNote, { size: 9 });
      y -= lineHeight;

      for (const ds of datasets) {
        drawText(ds.label, { size: 13, bold: true });
        if (ds.rows.length === 0) {
          drawText("(no data)", { size: 9 });
        } else {
          const headers = Object.keys(ds.rows[0]);
          drawText(headers.join(" | "), { size: 8, bold: true });
          for (const row of ds.rows) {
            const line = headers.map((h) => String(row[h] ?? "")).join(" | ");
            drawText(line.slice(0, 140), { size: 8 });
          }
        }
        y -= lineHeight / 2;
      }

      const buf = await pdfDoc.save();
      fileBytes = buf;
      ext = "pdf";
      contentType = "application/pdf";
    } else {
      return new Response(JSON.stringify({ error: "Unsupported format" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // ---------------------------------------------------------------
    // 3. Upload to storage, return a signed URL
    // ---------------------------------------------------------------
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const fileName = `${PROJECT_NAME}-export-${timestamp}.${ext}`;
    const path = `exports/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from("exports")
      .upload(path, fileBytes, { contentType, upsert: true });
    if (uploadError) throw new Error(`Upload failed: ${uploadError.message}`);

    const { data: signed, error: signError } = await supabase.storage
      .from("exports")
      .createSignedUrl(path, 300); // 5 minutes
    if (signError) throw new Error(`Signed URL failed: ${signError.message}`);

    return new Response(JSON.stringify({ downloadUrl: signed.signedUrl, fileName }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : "Export failed" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

"use client";

import { use, useState } from "react";
import Link from "next/link";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { useStore } from "@/lib/store";
import { z } from "zod";

const paymentAmountSchema = z.object({
  amount: z.coerce.number().positive("Amount must be greater than 0"),
});
type PaymentAmountValues = z.infer<typeof paymentAmountSchema>;

function RecordPaymentDialog({ open, onClose, customerId, customerName }: { open: boolean; onClose: () => void; customerId: string; customerName: string }) {
  const recordPayment = useStore((s) => s.recordPayment);
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm<PaymentAmountValues>({ resolver: zodResolver(paymentAmountSchema) });

  if (!open) return null;

  const onSubmit = async (values: PaymentAmountValues) => {
    recordPayment(customerId, values.amount, "Payment against invoice");
    toast.success(`Payment of Rs. ${values.amount.toLocaleString()} recorded for ${customerName}`);
    reset();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <form onSubmit={handleSubmit(onSubmit)} className="w-full max-w-sm rounded-xl border border-neutral-800 bg-neutral-900 p-5 space-y-4">
        <h2 className="text-lg font-semibold text-neutral-50">Record Payment â€” {customerName}</h2>
        <div>
          <label className="text-sm text-neutral-400">Amount</label>
          <input {...register("amount")} type="number" step="any"
            className="mt-1 w-full rounded-lg border border-neutral-800 bg-neutral-950 px-3 py-2 text-sm text-neutral-50 outline-none focus:border-neutral-600" />
          {errors.amount && <p className="text-xs text-red-400 mt-1">{errors.amount.message}</p>}
        </div>
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={() => { reset(); onClose(); }} className="rounded-lg px-4 py-2 text-sm text-neutral-300 hover:bg-neutral-800">Cancel</button>
          <button type="submit" disabled={isSubmitting}
            className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200 disabled:opacity-50">
            {isSubmitting ? "Saving..." : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}

export default function InvoiceDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const invoice = useStore((s) => s.invoices.find((i) => i.id === id));
  const settings = useStore((s) => s.settings);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [generatingPdf, setGeneratingPdf] = useState(false);

  if (!invoice) {
    return (
      <div className="space-y-4">
        <Link href="/invoices" className="text-sm text-neutral-400 hover:underline">&larr; Back to Invoices</Link>
        <p className="text-neutral-400">Invoice not found.</p>
      </div>
    );
  }

  const handleDownloadPDF = async () => {
    setGeneratingPdf(true);
    try {
      const { jsPDF } = await import("jspdf");
      const doc = new jsPDF({ unit: "pt", format: "a4" });

      const marginX = 48;
      let y = 56;

      doc.setFontSize(18);
      doc.setFont("helvetica", "bold");
      doc.text(settings.businessName || "GhaniFoods", marginX, y);

      doc.setFontSize(9);
      doc.setFont("helvetica", "normal");
      y += 16;
      doc.text(settings.address || "", marginX, y);

      doc.setFontSize(20);
      doc.setFont("helvetica", "bold");
      doc.text("INVOICE", 595 - marginX, 56, { align: "right" });
      doc.setFontSize(10);
      doc.setFont("helvetica", "normal");
      doc.text(invoice.id, 595 - marginX, 74, { align: "right" });
      doc.text(invoice.invoiceDate, 595 - marginX, 88, { align: "right" });

      y += 32;
      doc.setDrawColor(200);
      doc.line(marginX, y, 595 - marginX, y);

      y += 24;
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text("BILLED TO", marginX, y);
      y += 14;
      doc.setFontSize(12);
      doc.setTextColor(20);
      doc.setFont("helvetica", "bold");
      doc.text(invoice.customerName, marginX, y);
      doc.setFont("helvetica", "normal");

      y += 30;
      const colItem = marginX;
      const colQty = 330;
      const colPrice = 400;
      const colSubtotal = 500;

      doc.setFillColor(23, 23, 23);
      doc.rect(marginX, y - 14, 595 - marginX * 2, 22, "F");
      doc.setTextColor(255);
      doc.setFontSize(9);
      doc.setFont("helvetica", "bold");
      doc.text("ITEM", colItem + 6, y + 1);
      doc.text("QTY", colQty, y + 1);
      doc.text("UNIT PRICE", colPrice, y + 1);
      doc.text("SUBTOTAL", colSubtotal, y + 1);

      y += 22;
      doc.setTextColor(30);
      doc.setFont("helvetica", "normal");
      doc.setFontSize(10);

      const lines = invoice.items.length > 0
        ? invoice.items
        : [{ itemName: "Nimko Carton (legacy record)", qty: 0, unitPrice: 0, subtotal: invoice.totalAmount, itemId: "" }];

      for (const line of lines) {
        doc.text(String(line.itemName), colItem + 6, y);
        doc.text(line.qty ? String(line.qty) : "-", colQty, y);
        doc.text(line.unitPrice ? `Rs. ${line.unitPrice.toLocaleString()}` : "-", colPrice, y);
        doc.text(`Rs. ${line.subtotal.toLocaleString()}`, colSubtotal, y);
        y += 20;
        doc.setDrawColor(230);
        doc.line(marginX, y - 6, 595 - marginX, y - 6);
      }

      y += 20;
      doc.setFont("helvetica", "bold");
      doc.setFontSize(12);
      doc.text("Total:", colPrice, y);
      doc.text(`Rs. ${invoice.totalAmount.toLocaleString()}`, colSubtotal, y);

      y += 50;
      doc.setFont("helvetica", "normal");
      doc.setFontSize(9);
      doc.setTextColor(120);
      doc.text(settings.invoiceFooterText || "Thank you for your business!", marginX, y);

      doc.save(`${invoice.id}.pdf`);
      toast.success(`Invoice ${invoice.id} downloaded as PDF`);
    } catch (err) {
      toast.error("Could not generate PDF. Please try again.");
      console.error(err);
    } finally {
      setGeneratingPdf(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="text-sm text-neutral-400">
        <Link href="/invoices" className="hover:underline text-neutral-300">Invoices</Link>{" "}
        / <span className="text-neutral-50">{invoice.id}</span>
      </div>

      <div className="rounded-xl border border-neutral-800 bg-neutral-900 p-6 print:border-0">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-xl font-semibold text-neutral-50">Invoice {invoice.id}</h1>
            <p className="text-sm text-neutral-400 mt-1">{invoice.invoiceDate}</p>
          </div>
          <div className="text-right">
            <div className="text-neutral-400 text-xs">Billed To</div>
            <div className="text-neutral-50 font-medium">{invoice.customerName}</div>
          </div>
        </div>

        <div className="mt-6 rounded-lg border border-neutral-800 overflow-hidden">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-neutral-800 bg-neutral-950 text-left text-neutral-400">
                <th className="px-4 py-2 font-medium">Item</th>
                <th className="px-4 py-2 font-medium">Qty</th>
                <th className="px-4 py-2 font-medium">Unit Price</th>
                <th className="px-4 py-2 font-medium">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              {invoice.items.length > 0 ? (
                invoice.items.map((line, idx) => (
                  <tr key={idx}>
                    <td className="px-4 py-2 text-neutral-300">{line.itemName}</td>
                    <td className="px-4 py-2 text-neutral-300">{line.qty}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.unitPrice.toLocaleString()}</td>
                    <td className="px-4 py-2 text-neutral-300">Rs. {line.subtotal.toLocaleString()}</td>
                  </tr>
                ))
              ) : (
                <tr>
                  <td className="px-4 py-2 text-neutral-300">Nimko Carton (legacy record)</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">-</td>
                  <td className="px-4 py-2 text-neutral-300">Rs. {invoice.totalAmount.toLocaleString()}</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        <div className="mt-4 flex justify-end">
          <div className="text-lg font-semibold text-neutral-50">Total: Rs. {invoice.totalAmount.toLocaleString()}</div>
        </div>
      </div>

      <div className="flex gap-2 print:hidden">
        <button onClick={() => window.print()} className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800">Print</button>
        <button
          onClick={handleDownloadPDF}
          disabled={generatingPdf}
          className="rounded-lg border border-neutral-700 px-4 py-2 text-sm text-neutral-200 hover:bg-neutral-800 disabled:opacity-50"
        >
          {generatingPdf ? "Generating..." : "Download PDF"}
        </button>
        <button onClick={() => setDialogOpen(true)} className="rounded-lg bg-neutral-50 px-4 py-2 text-sm font-medium text-neutral-950 hover:bg-neutral-200">
          Record Payment
        </button>
      </div>

      <RecordPaymentDialog open={dialogOpen} onClose={() => setDialogOpen(false)} customerId={invoice.customerId} customerName={invoice.customerName} />
    </div>
  );
}
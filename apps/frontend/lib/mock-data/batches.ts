// lib/mock-data/batches.ts
export type ProductionBatch = {
  id: string;
  batchDate: string;
  outputYieldKg: number;
  wastageKg: number;
  leftoverQtyKg: number;
  bulkCostPerKg: number;
  status: "in_progress" | "completed";
};

export const productionBatches: ProductionBatch[] = [
  { id: "batch-1", batchDate: "2026-08-10", outputYieldKg: 500, wastageKg: 8, leftoverQtyKg: 40, bulkCostPerKg: 210.75, status: "completed" },
  { id: "batch-2", batchDate: "2026-08-13", outputYieldKg: 480, wastageKg: 5, leftoverQtyKg: 480, bulkCostPerKg: 205.3, status: "completed" },
  { id: "batch-3", batchDate: "2026-08-16", outputYieldKg: 300, wastageKg: 0, leftoverQtyKg: 0, bulkCostPerKg: 0, status: "in_progress" },
];
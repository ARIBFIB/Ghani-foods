// lib/mock-data/finished-cartons.ts
export type FinishedCarton = {
  id: string;
  name: string;
  sourceBatchId: string;
  packetsPerCarton: number;
  costPerCarton: number;
  stockQty: number;
};

export const finishedCartons: FinishedCarton[] = [
  { id: "fc-1", name: "Nimko Carton - 24pk", sourceBatchId: "batch-1", packetsPerCarton: 24, costPerCarton: 610, stockQty: 85 },
  { id: "fc-2", name: "Nimko Carton - 48pk", sourceBatchId: "batch-2", packetsPerCarton: 48, costPerCarton: 1150, stockQty: 42 },
];
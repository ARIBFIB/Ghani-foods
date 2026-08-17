// lib/mock-data/packaging.ts
export type PackagingMaterial = {
  id: string;
  name: string;
  unitCost: number;
  stockQty: number;
  lowStockThreshold: number;
};

export const packagingMaterials: PackagingMaterial[] = [
  { id: "pm-1", name: "Carton Box (Large)", unitCost: 45, stockQty: 320, lowStockThreshold: 100 },
  { id: "pm-2", name: "Shopper Bag", unitCost: 3.5, stockQty: 2400, lowStockThreshold: 500 },
  { id: "pm-3", name: "Dabbe (Tin)", unitCost: 22, stockQty: 150, lowStockThreshold: 60 },
];
// lib/mock-data/raw-materials.ts
export type RawMaterial = {
  id: string;
  name: string;
  unit: string;
  quantityInStock: number;
  avgUnitCost: number;
  lowStockThreshold: number;
};

export const rawMaterials: RawMaterial[] = [
  { id: "rm-1", name: "Atta (Flour)", unit: "kg", quantityInStock: 420, avgUnitCost: 145.5, lowStockThreshold: 100 },
  { id: "rm-2", name: "Ghee", unit: "kg", quantityInStock: 65, avgUnitCost: 780, lowStockThreshold: 80 },
  { id: "rm-3", name: "Salt", unit: "kg", quantityInStock: 210, avgUnitCost: 28, lowStockThreshold: 50 },
  { id: "rm-4", name: "Spice Mix", unit: "kg", quantityInStock: 34, avgUnitCost: 620, lowStockThreshold: 40 },
];
// lib/mock-data/customer-item-prices.ts
export type CustomerItemPrice = {
  customerId: string;
  itemId: string;
  lastSoldPrice: number;
};

export const customerItemPrices: CustomerItemPrice[] = [
  { customerId: "cust-1", itemId: "fc-1", lastSoldPrice: 640 },
  { customerId: "cust-2", itemId: "fc-2", lastSoldPrice: 1180 },
];
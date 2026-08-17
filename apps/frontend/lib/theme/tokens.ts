// lib/theme/tokens.ts
// GhaniFoods design tokens - single source of truth for Ant Design ConfigProvider

export const colorTokens = {
  colorPrimary: "#1F4E79",     // deep blue - primary actions, headers
  colorSuccess: "#2E7D32",     // stock OK / paid
  colorWarning: "#C77700",     // low stock / partial payment
  colorError: "#B3261E",       // out of stock / overdue balance
  colorInfo: "#0958D9",
  colorTextBase: "#1A1A1A",
  colorBgLayout: "#F5F6F8",
  colorBgContainer: "#FFFFFF",
  colorBorder: "#E3E6EA",
};

export const typographyTokens = {
  fontFamily: "'Inter', 'Segoe UI', -apple-system, sans-serif",
  fontFamilyMono: "'IBM Plex Mono', 'Courier New', monospace",
  fontSizeBase: 14,
  fontSizeHeading1: 30,
  fontSizeHeading2: 24,
  fontSizeHeading3: 18,
};

export const radiusTokens = {
  borderRadius: 8,
  borderRadiusLG: 12,
  borderRadiusSM: 6,
};

export const spacingTokens = {
  paddingContentHorizontal: 24,
  paddingContentVertical: 16,
  marginXS: 8,
  marginSM: 12,
  marginMD: 16,
  marginLG: 24,
};

// Domain-specific semantic colors (not part of AntD token API,
// used directly in components e.g. balance badges, status pills)
export const semanticTokens = {
  balanceOwes: "#B3261E",
  balanceCredit: "#2E7D32",
  statusReady: "#2E7D32",
  statusLeftover: "#C77700",
  statusLow: "#B3261E",
  statusPaid: "#2E7D32",
  statusUnpaid: "#B3261E",
  statusPartial: "#C77700",
};

export const antdThemeConfig = {
  token: {
    ...colorTokens,
    ...typographyTokens,
    ...radiusTokens,
    ...spacingTokens,
  },
  components: {
    Table: { headerBg: "#1F4E79", headerColor: "#FFFFFF" },
    Card: { borderRadiusLG: 12 },
    Button: { borderRadius: 8, controlHeight: 38 },
  },
};
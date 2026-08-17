// components/layout/AntdThemeProvider.tsx
"use client";

import { ConfigProvider } from "antd";
import { AntdRegistry } from "@ant-design/nextjs-registry";
import { antdThemeConfig } from "@/lib/theme/tokens";

export default function AntdThemeProvider({ children }: { children: React.ReactNode }) {
  return (
    <AntdRegistry>
      <ConfigProvider theme={antdThemeConfig}>{children}</ConfigProvider>
    </AntdRegistry>
  );
}
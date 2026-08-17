// app/(dashboard)/page.tsx
import { Card, Col, Row, Statistic, Table, Tag } from "antd";
import { dashboardKpis } from "@/lib/mock-data/kpis";
import { invoices } from "@/lib/mock-data/invoices";

export default function DashboardPage() {
  const recent = invoices.slice(0, 5);

  return (
    <div style={{ padding: 24 }}>
      <Row gutter={16}>
        <Col span={6}>
          <Card><Statistic title="Raw Material Value" value={dashboardKpis.totalRawMaterialValue} prefix="Rs." /></Card>
        </Col>
        <Col span={6}>
          <Card><Statistic title="Batches This Month" value={dashboardKpis.batchesThisMonth} /></Card>
        </Col>
        <Col span={6}>
          <Card><Statistic title="Finished Cartons Ready" value={dashboardKpis.finishedCartonsReady} /></Card>
        </Col>
        <Col span={6}>
          <Card><Statistic title="Total Receivables" value={dashboardKpis.totalReceivables} prefix="Rs." /></Card>
        </Col>
      </Row>

      <Card title="Recent Invoices" style={{ marginTop: 24 }}>
        <Table
          rowKey="id"
          dataSource={recent}
          pagination={false}
          columns={[
            { title: "Invoice #", dataIndex: "id" },
            { title: "Customer", dataIndex: "customerName" },
            { title: "Date", dataIndex: "invoiceDate" },
            { title: "Total", dataIndex: "totalAmount", render: (v: number) => `Rs. ${v.toLocaleString()}` },
            {
              title: "Status",
              dataIndex: "status",
              render: (s: string) => {
                const color = s === "paid" ? "green" : s === "partial" ? "orange" : "red";
                return <Tag color={color}>{s.toUpperCase()}</Tag>;
              },
            },
          ]}
        />
      </Card>
    </div>
  );
}
import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ActionVisitorDialog } from "./components/action-visitor-dialog"
import { visitorsApi, VisitorRequestItem } from "./api/visitors-api"
import { formatDate } from "@/lib/utils"
import {
  UserCheck,
  Building,
  Clock,
  Shield,
  CheckCircle2,
  RefreshCw,
  QrCode,
} from "lucide-react"

export function VisitorsPage() {
  const [selectedRequest, setSelectedRequest] = React.useState<VisitorRequestItem | null>(null)
  const [actionType, setActionType] = React.useState<"APPROVE" | "REJECT" | null>(null)
  const [actionOpen, setActionOpen] = React.useState(false)

  const { data: kpis } = useQuery({
    queryKey: ["visitors", "kpis"],
    queryFn: visitorsApi.getKpis,
  })

  const {
    data: pendingVisitors = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["visitors", "pending"],
    queryFn: visitorsApi.getPendingRequests,
  })

  const columns: ColumnDef<VisitorRequestItem>[] = [
    {
      accessorKey: "visitor_name",
      header: "Visitor Details",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.visitor_name}</p>
          <p className="text-[10px] text-muted-foreground">
            {row.original.relation} • {row.original.visitor_phone}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "studentName",
      header: "Host Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber} ({row.original.branch})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "purpose",
      header: "Purpose of Visit",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground max-w-xs truncate block">
          {row.original.purpose}
        </span>
      ),
    },
    {
      accessorKey: "visit_date",
      header: "Visit Date & Time",
      cell: ({ row }) => (
        <div className="text-[11px] text-muted-foreground font-mono space-y-0.5">
          <p>{row.original.visit_date}</p>
          <p>{row.original.expected_entry_time} – {row.original.expected_exit_time}</p>
        </div>
      ),
    },
    {
      accessorKey: "pass_code",
      header: "Pass Code",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-foreground">
          {row.original.pass_code || "Generated on Approval"}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Pass State",
      cell: ({ row }) => {
        const s = row.original.status
        const variant =
          s === "CHECKED_IN"
            ? "success"
            : s === "APPROVED"
            ? "info"
            : s === "REJECTED"
            ? "destructive"
            : "secondary"
        return (
          <Badge variant={variant} className="text-[10px] font-mono">
            {s}
          </Badge>
        )
      },
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const r = row.original
        if (r.status === "PENDING") {
          return (
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedRequest(r)
                  setActionType("APPROVE")
                  setActionOpen(true)
                }}
              >
                Approve
              </Button>
              <Button
                variant="destructive"
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedRequest(r)
                  setActionType("REJECT")
                  setActionOpen(true)
                }}
              >
                Reject
              </Button>
            </div>
          )
        }
        return <span className="text-[11px] text-muted-foreground font-mono">{r.status}</span>
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Visitor Control Plane"
        description="Campus guest verification, host student linkage, pass credentials, and entry/exit audit."
        badge={
          <StatusIndicator
            status="success"
            label={`${kpis?.insideCampusNow ?? 0} Guests on Campus`}
          />
        }
        actions={
          <Button variant="outline" size="sm" onClick={() => refetch()} className="text-xs gap-1.5">
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {/* Visitor KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Currently on Campus</p>
          <p className="text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            {kpis?.insideCampusNow ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Active perimeter badges</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Pending Approvals</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {kpis?.pendingApprovals ?? pendingVisitors.length}
          </p>
          <p className="text-[11px] text-muted-foreground">Awaiting Warden review</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Approved Passes</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis?.approvedPasses ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Awaiting campus arrival</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Completed Visits Today</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis?.completedVisitsToday ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Checked out at gate</p>
        </div>
      </div>

      <div className="space-y-3">
        <div>
          <h2 className="text-sm font-semibold tracking-tight text-foreground">
            Visitor Access Queue & Approvals
          </h2>
          <p className="text-xs text-muted-foreground">
            Pass authorization requests filed by enrolled residents
          </p>
        </div>

        <DataTable
          columns={columns}
          data={pendingVisitors}
          isLoading={isLoading}
          error={error}
          onRetry={refetch}
          searchPlaceholder="Search visitor or student name..."
          searchColumnId="visitor_name"
          emptyTitle="No Pending Visitor Passes"
          emptyDescription="There are currently no visitor pass requests awaiting institutional approval."
        />
      </div>

      <ActionVisitorDialog
        request={selectedRequest}
        action={actionType}
        open={actionOpen}
        onOpenChange={setActionOpen}
      />
    </div>
  )
}

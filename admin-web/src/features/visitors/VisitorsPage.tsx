import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { useToast } from "@/components/ui/toast"
import { ActionVisitorDialog } from "./components/action-visitor-dialog"
import { visitorsApi, VisitorRequestItem } from "./api/visitors-api"
import {
  RefreshCw,
  LogIn,
  LogOut,
  QrCode,
} from "lucide-react"

export function VisitorsPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [statusFilter, setStatusFilter] = React.useState<string>("ALL")
  const [passCodeInput, setPassCodeInput] = React.useState("")
  const [selectedRequest, setSelectedRequest] = React.useState<VisitorRequestItem | null>(null)
  const [actionType, setActionType] = React.useState<"APPROVE" | "REJECT" | null>(null)
  const [actionOpen, setActionOpen] = React.useState(false)

  const { data: kpis } = useQuery({
    queryKey: ["visitors", "kpis"],
    queryFn: visitorsApi.getKpis,
  })

  const {
    data: visitors = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["visitors", "all", statusFilter],
    queryFn: () => visitorsApi.getAllRequests(statusFilter),
  })

  const checkInMutation = useMutation({
    mutationFn: (passCode: string) => visitorsApi.checkInVisitor(passCode.trim().toUpperCase()),
    onSuccess: (res) => {
      toast({
        title: "Visitor Checked In",
        description: res.message || `${res.pass.visitorName} entered campus.`,
        type: "success",
      })
      setPassCodeInput("")
      queryClient.invalidateQueries({ queryKey: ["visitors"] })
    },
    onError: (err: Error) => {
      toast({
        title: "Check-In Failed",
        description: err.message || "Invalid or expired pass code.",
        type: "error",
      })
    },
  })

  const checkOutMutation = useMutation({
    mutationFn: (passCode: string) => visitorsApi.checkOutVisitor(passCode.trim().toUpperCase()),
    onSuccess: (res) => {
      toast({
        title: "Visitor Checked Out",
        description: res.message || `${res.pass.visitorName} exited campus.`,
        type: "success",
      })
      setPassCodeInput("")
      queryClient.invalidateQueries({ queryKey: ["visitors"] })
    },
    onError: (err: Error) => {
      toast({
        title: "Check-Out Failed",
        description: err.message || "Visitor is not currently checked in.",
        type: "error",
      })
    },
  })

  const columns: ColumnDef<VisitorRequestItem>[] = [
    {
      accessorKey: "visitorName",
      header: "Visitor Details",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.visitorName}</p>
          <p className="text-[10px] text-muted-foreground">
            {row.original.relation} • {row.original.visitorPhone}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "studentName",
      header: "Host Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName || "Host"}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch || "—"})
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
      accessorKey: "visitDate",
      header: "Visit Date & Time",
      cell: ({ row }) => (
        <div className="text-[11px] text-muted-foreground font-mono space-y-0.5">
          <p>{row.original.visitDate}</p>
          <p>
            {row.original.expectedEntryTime} – {row.original.expectedExitTime}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "passCode",
      header: "Pass Code",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {row.original.passCode || "Pending Approval"}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Pass State",
      cell: ({ row }) => {
        const s = row.original.status
        const variant =
          s === "CHECKED_IN" || s === "CHECKED_OUT"
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
        if (r.status === "APPROVED" && r.passCode) {
          return (
            <Button
              size="sm"
              variant="outline"
              className="h-7 text-xs gap-1 text-emerald-600 border-emerald-500/30 hover:bg-emerald-500/10"
              loading={checkInMutation.isPending && checkInMutation.variables === r.passCode}
              onClick={() => checkInMutation.mutate(r.passCode!)}
            >
              <LogIn className="h-3 w-3" /> Check In
            </Button>
          )
        }
        if (r.status === "CHECKED_IN" && r.passCode) {
          return (
            <Button
              size="sm"
              variant="outline"
              className="h-7 text-xs gap-1"
              loading={checkOutMutation.isPending && checkOutMutation.variables === r.passCode}
              onClick={() => checkOutMutation.mutate(r.passCode!)}
            >
              <LogOut className="h-3 w-3" /> Check Out
            </Button>
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
        description="Campus guest verification, host student linkage, pass credentials, and gate check-in/out."
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
            {kpis?.pendingApprovals ?? 0}
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

      {/* Quick Security Pass Code Gate Check-In / Check-Out */}
      <div className="rounded-xl border border-border/80 bg-card p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-2.5">
          <div className="p-2 rounded-lg bg-primary/10 text-primary">
            <QrCode className="h-4 w-4" />
          </div>
          <div>
            <h3 className="text-xs font-semibold text-foreground">Security Desk Pass Code Scanner</h3>
            <p className="text-[11px] text-muted-foreground">
              Enter a visitor pass code (e.g. VIS-123456) to log gate entry or exit immediately.
            </p>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Input
            value={passCodeInput}
            onChange={(e) => setPassCodeInput(e.target.value)}
            placeholder="Pass Code..."
            className="h-8 w-44 text-xs font-mono uppercase"
          />
          <Button
            size="sm"
            className="h-8 text-xs gap-1"
            disabled={!passCodeInput.trim()}
            loading={checkInMutation.isPending}
            onClick={() => checkInMutation.mutate(passCodeInput)}
          >
            <LogIn className="h-3.5 w-3.5" /> Check In
          </Button>
          <Button
            size="sm"
            variant="outline"
            className="h-8 text-xs gap-1"
            disabled={!passCodeInput.trim()}
            loading={checkOutMutation.isPending}
            onClick={() => checkOutMutation.mutate(passCodeInput)}
          >
            <LogOut className="h-3.5 w-3.5" /> Check Out
          </Button>
        </div>
      </div>

      <div className="space-y-3">
        <div>
          <h2 className="text-sm font-semibold tracking-tight text-foreground">
            Visitor Registry & Pass Queue
          </h2>
          <p className="text-xs text-muted-foreground">
            All visitor pass requests, active guest badges, and completed gate visits
          </p>
        </div>

        <DataTable
          columns={columns}
          data={visitors}
          isLoading={isLoading}
          error={error}
          onRetry={refetch}
          searchPlaceholder="Search visitor, host student, reg #, or pass code..."
          emptyTitle="No Visitor Passes Found"
          emptyDescription="There are currently no visitor pass requests matching the selected status."
          toolbarSlot={
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-40 h-8 text-xs bg-card">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">All Visitors</SelectItem>
                <SelectItem value="PENDING">Pending Approval</SelectItem>
                <SelectItem value="APPROVED">Approved (Awaiting Gate)</SelectItem>
                <SelectItem value="CHECKED_IN">Checked In (On Campus)</SelectItem>
                <SelectItem value="CHECKED_OUT">Checked Out</SelectItem>
                <SelectItem value="REJECTED">Rejected</SelectItem>
              </SelectContent>
            </Select>
          }
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

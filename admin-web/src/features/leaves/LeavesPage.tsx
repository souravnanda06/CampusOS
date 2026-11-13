import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import {
  CalendarClock,
  CheckCircle2,
  XCircle,
  MessageSquare,
  RefreshCw,
  ShieldCheck,
  MapPin,
} from "lucide-react"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { StatusIndicator } from "@/components/ui/status-indicator"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { useToast } from "@/components/ui/toast"
import { formatRelativeTime } from "@/lib/utils"
import { leavesApi, LeaveRequestItem } from "./api/leaves-api"

export function LeavesPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [statusFilter, setStatusFilter] = React.useState<string>("ALL")
  const [selectedLeave, setSelectedLeave] = React.useState<LeaveRequestItem | null>(null)
  const [actionType, setActionType] = React.useState<"APPROVE" | "REJECT" | "ASK_STUDENT" | null>(null)
  const [remarks, setRemarks] = React.useState("")

  const { data: summary } = useQuery({
    queryKey: ["warden", "summary"],
    queryFn: leavesApi.getSummary,
  })

  const {
    data: leaves = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["warden", "leaves", statusFilter],
    queryFn: () => leavesApi.getLeaveRequests({ status: statusFilter }),
  })

  const actionMutation = useMutation({
    mutationFn: () =>
      leavesApi.actionLeaveRequest(
        selectedLeave?.id || "",
        actionType || "APPROVE",
        remarks.trim() || undefined
      ),
    onSuccess: (res) => {
      toast({
        title: `Leave ${actionType === "APPROVE" ? "Approved" : actionType === "REJECT" ? "Rejected" : "Clarification Sent"}`,
        description: res.message,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["warden"] })
      queryClient.invalidateQueries({ queryKey: ["security"] })
      setSelectedLeave(null)
      setActionType(null)
      setRemarks("")
    },
    onError: (err: unknown) => {
      toast({
        title: "Action Failed",
        description: err instanceof Error ? err.message : "Failed to process leave request",
        type: "error",
      })
    },
  })

  const openAction = (leave: LeaveRequestItem, type: "APPROVE" | "REJECT" | "ASK_STUDENT") => {
    setSelectedLeave(leave)
    setActionType(type)
    setRemarks("")
  }

  const columns: ColumnDef<LeaveRequestItem>[] = [
    {
      accessorKey: "studentName",
      header: "Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName || "Student"}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch || "Gen"} Yr {row.original.year || "1"})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "leaveType",
      header: "Type & Destination",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <Badge variant="outline" className="text-[10px] font-mono">
            {row.original.leaveType}
          </Badge>
          {row.original.destination && (
            <p className="text-[11px] text-muted-foreground flex items-center gap-1">
              <MapPin className="h-3 w-3" /> {row.original.destination}
            </p>
          )}
        </div>
      ),
    },
    {
      accessorKey: "startDate",
      header: "Duration",
      cell: ({ row }) => (
        <div className="text-[11px] font-mono text-foreground space-y-0.5">
          <p>{row.original.startDate} → {row.original.endDate}</p>
          <p className="text-[10px] text-muted-foreground">
            Filed {formatRelativeTime(row.original.createdAt)}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "reason",
      header: "Reason & Consent",
      cell: ({ row }) => (
        <div className="space-y-0.5 max-w-xs">
          <p className="text-xs text-foreground truncate">{row.original.reason}</p>
          <p className="text-[10px] font-mono text-muted-foreground">
            Parent Consent: {row.original.parentConsent}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => (
        <StatusIndicator status={row.original.status} label={row.original.status} size="sm" />
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const l = row.original
        if (l.status !== "PENDING") {
          return (
            <span className="text-[11px] font-mono text-muted-foreground">
              {l.reviewRemarks || l.status}
            </span>
          )
        }
        return (
          <div className="flex items-center gap-1.5">
            <Button
              size="sm"
              className="h-7 text-xs gap-1"
              onClick={() => openAction(l, "APPROVE")}
            >
              <CheckCircle2 className="h-3 w-3" /> Approve
            </Button>
            <Button
              size="sm"
              variant="outline"
              className="h-7 text-xs gap-1"
              onClick={() => openAction(l, "ASK_STUDENT")}
            >
              <MessageSquare className="h-3 w-3" /> Query
            </Button>
            <Button
              size="sm"
              variant="destructive"
              className="h-7 text-xs gap-1"
              onClick={() => openAction(l, "REJECT")}
            >
              <XCircle className="h-3 w-3" /> Reject
            </Button>
          </div>
        )
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Leave & Gate Pass Approvals"
        description="Warden and Dean authorization queue for student leave requests and automated Gate Pass issuance."
        badge={
          <StatusIndicator
            status={(summary?.pendingRequests ?? 0) > 0 ? "warning" : "success"}
            label={`${summary?.pendingRequests ?? 0} Pending Reviews`}
          />
        }
        actions={
          <Button variant="outline" size="sm" onClick={() => refetch()} className="text-xs gap-1.5">
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Pending Leaves</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {summary?.pendingRequests ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Awaiting authorization</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Approved Today</p>
          <p className="text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            {summary?.approvedToday ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Cleared with gate credentials</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Active Gate Passes</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {summary?.activeGatePasses ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Issued or currently outside</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Pending Visitor Passes</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {summary?.pendingVisitors ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Co-managed in Visitors</p>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={leaves}
        isLoading={isLoading}
        error={error}
        onRetry={refetch}
        searchPlaceholder="Search by student, reg #, destination, or reason..."
        emptyTitle="No Leave Requests Found"
        emptyDescription="There are no student leave requests matching the selected status."
        toolbarSlot={
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-36 h-8 text-xs bg-card">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Requests</SelectItem>
              <SelectItem value="PENDING">Pending</SelectItem>
              <SelectItem value="APPROVED">Approved</SelectItem>
              <SelectItem value="REJECTED">Rejected</SelectItem>
            </SelectContent>
          </Select>
        }
      />

      <Dialog
        open={!!selectedLeave && !!actionType}
        onOpenChange={(open) => {
          if (!open) {
            setSelectedLeave(null)
            setActionType(null)
          }
        }}
      >
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <CalendarClock className="h-4 w-4 text-primary" />
              {actionType === "APPROVE"
                ? "Approve Leave & Issue Gate Pass"
                : actionType === "REJECT"
                ? "Reject Leave Request"
                : "Request Student Clarification"}
            </DialogTitle>
            <DialogDescription>
              {selectedLeave?.studentName} ({selectedLeave?.leaveType}: {selectedLeave?.startDate} → {selectedLeave?.endDate})
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3 py-2 text-xs">
            <div className="rounded-lg bg-muted/40 p-3 border border-border/60 space-y-1">
              <p className="font-medium text-foreground">Reason:</p>
              <p className="text-muted-foreground">{selectedLeave?.reason}</p>
            </div>
            {actionType === "APPROVE" && (
              <div className="flex items-center gap-2 rounded-lg bg-emerald-500/10 border border-emerald-500/30 p-2.5 text-emerald-700 dark:text-emerald-300">
                <ShieldCheck className="h-4 w-4 shrink-0" />
                <span>Approving automatically activates any linked student Gate Pass.</span>
              </div>
            )}
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">
                Warden / Admin Remarks {actionType === "REJECT" || actionType === "ASK_STUDENT" ? "(Required)" : "(Optional)"}
              </label>
              <Input
                value={remarks}
                onChange={(e) => setRemarks(e.target.value)}
                placeholder="Enter remarks for the student and audit trail..."
                className="h-9 text-xs"
              />
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                setSelectedLeave(null)
                setActionType(null)
              }}
            >
              Cancel
            </Button>
            <Button
              size="sm"
              variant={actionType === "REJECT" ? "destructive" : "default"}
              disabled={(actionType === "REJECT" || actionType === "ASK_STUDENT") && !remarks.trim()}
              loading={actionMutation.isPending}
              onClick={() => actionMutation.mutate()}
            >
              {actionType === "APPROVE"
                ? "Approve Leave"
                : actionType === "REJECT"
                ? "Reject Leave"
                : "Send Query"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

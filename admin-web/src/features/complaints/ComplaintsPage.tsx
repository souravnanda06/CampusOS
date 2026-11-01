import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { useSearchParams, useParams } from "react-router-dom"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { useToast } from "@/components/ui/toast"
import { ComplaintDetailSheet } from "./components/complaint-detail-sheet"
import { complaintsApi, AdminComplaint, RecurringCluster } from "./api/complaints-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  AlertCircle,
  Clock,
  Repeat,
  MapPin,
  ExternalLink,
  Flame,
  CheckCircle2,
  Filter,
  ShieldCheck,
  Zap,
  TrendingUp,
  AlertTriangle,
  RotateCw,
} from "lucide-react"

export function ComplaintsPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const { id: routeComplaintId } = useParams()

  const [selectedComplaintId, setSelectedComplaintId] = React.useState<string | null>(null)
  const [sheetOpen, setSheetOpen] = React.useState(false)
  const [isEvaluating, setIsEvaluating] = React.useState(false)
  const { toast } = useToast()

  React.useEffect(() => {
    if (routeComplaintId) {
      setSelectedComplaintId(routeComplaintId)
      setSheetOpen(true)
    }
  }, [routeComplaintId])

  const statusParam = searchParams.get("status") || "ALL"
  const priorityParam = searchParams.get("priority") || "ALL"
  const categoryParam = searchParams.get("category") || "ALL"
  const ageingParam = searchParams.get("ageing") === "true"

  const {
    data: complaints = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["admin", "complaints", statusParam, priorityParam, categoryParam, ageingParam],
    queryFn: () =>
      complaintsApi.getComplaints({
        status: statusParam !== "ALL" ? statusParam : undefined,
        priority: priorityParam !== "ALL" ? priorityParam : undefined,
        category: categoryParam !== "ALL" ? categoryParam : undefined,
        ageing: ageingParam ? true : undefined,
      }),
  })

  // Slingshot Executive Metrics
  const {
    data: slingshotData,
    isLoading: isSlingshotLoading,
    refetch: refetchSlingshot,
  } = useQuery({
    queryKey: ["admin", "complaints", "slingshot"],
    queryFn: complaintsApi.getSlingshotDashboard,
  })

  // Recurring clusters
  const { data: recurringClusters = [], isLoading: isRecurringLoading } = useQuery({
    queryKey: ["admin", "complaints", "recurring"],
    queryFn: complaintsApi.getRecurringClusters,
  })

  const handleEvaluateSlingshot = async () => {
    try {
      setIsEvaluating(true)
      const res = await complaintsApi.evaluateSlingshot()
      await Promise.all([refetch(), refetchSlingshot()])
      toast({
        title: "⚡ SLA Slingshot Evaluated",
        description: `Evaluated ${res.evaluatedCount} active tickets. ${res.escalatedToTier2Count} escalated to Tier 2 (Warden Alert), ${res.escalatedToTier3Count} escalated to Tier 3 (Dean Slingshot + ₹500 Vendor Penalty).`,
        type: "success",
      })
    } catch (err: any) {
      toast({
        title: "Evaluation Failed",
        description: err?.response?.data?.error || err.message || "Failed to trigger SLA Slingshot evaluation",
        type: "error",
      })
    } finally {
      setIsEvaluating(false)
    }
  }

  const handleRowClick = (complaint: AdminComplaint) => {
    setSelectedComplaintId(complaint.id)
    setSheetOpen(true)
  }

  const handleStatusFilterChange = (val: string) => {
    const next = new URLSearchParams(searchParams)
    if (val === "ALL") next.delete("status")
    else next.set("status", val)
    setSearchParams(next)
  }

  const handlePriorityFilterChange = (val: string) => {
    const next = new URLSearchParams(searchParams)
    if (val === "ALL") next.delete("priority")
    else next.set("priority", val)
    setSearchParams(next)
  }

  const handleCategoryFilterChange = (val: string) => {
    const next = new URLSearchParams(searchParams)
    if (val === "ALL") next.delete("category")
    else next.set("category", val)
    setSearchParams(next)
  }

  const toggleAgeingFilter = () => {
    const next = new URLSearchParams(searchParams)
    if (ageingParam) next.delete("ageing")
    else next.set("ageing", "true")
    setSearchParams(next)
  }

  const columns: ColumnDef<AdminComplaint>[] = [
    {
      accessorKey: "id",
      header: "Ticket ID",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          #{row.original.id.slice(0, 8)}
        </span>
      ),
    },
    {
      accessorKey: "title",
      header: "Issue Title",
      cell: ({ row }) => (
        <div className="space-y-0.5 min-w-[200px] max-w-sm">
          <p className="font-semibold text-xs text-foreground group-hover:text-primary transition-colors truncate">
            {row.original.title}
          </p>
          <p className="text-[11px] text-muted-foreground truncate">{row.original.location || "Campus"}</p>
        </div>
      ),
    },
    {
      accessorKey: "category",
      header: "Category",
      cell: ({ row }) => (
        <span className="text-xs font-medium text-foreground">
          {row.getValue("category")}
        </span>
      ),
    },
    {
      accessorKey: "priority",
      header: "Priority",
      cell: ({ row }) => {
        const priority = row.getValue("priority") as string
        const variant =
          priority === "URGENT"
            ? "destructive"
            : priority === "HIGH"
            ? "warning"
            : "secondary"
        return (
          <Badge variant={variant} className="text-[10px] font-mono">
            {priority}
          </Badge>
        )
      },
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => {
        const status = row.getValue("status") as string
        return <StatusIndicator status={status} label={status} size="sm" />
      },
    },
    {
      accessorKey: "escalationLevel",
      header: "SLA / Proof-of-Fix",
      cell: ({ row }) => {
        const c = row.original
        const isClosedOrResolved = c.status === "RESOLVED" || c.status === "CLOSED"

        if (isClosedOrResolved) {
          return (
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-semibold font-mono bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border border-emerald-500/30">
                <ShieldCheck className="h-3 w-3" />
                OTP Verified
              </span>
              {c.studentRating ? (
                <span className="text-[11px] font-bold text-amber-500 flex items-center">
                  ★{c.studentRating}
                </span>
              ) : null}
            </div>
          )
        }

        if (c.escalationLevel === 3) {
          return (
            <div className="flex items-center gap-1.5 flex-wrap">
              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-semibold font-mono bg-rose-500/15 text-rose-600 dark:text-rose-400 border border-rose-500/30 animate-pulse">
                <Flame className="h-3 w-3 text-rose-500" />
                Tier 3 Dean
              </span>
              {c.vendorPenaltyFlag && (
                <span className="text-[10px] font-mono font-bold text-rose-500">
                  -₹{c.vendorPenaltyAmount || 500}
                </span>
              )}
            </div>
          )
        }

        if (c.escalationLevel === 2) {
          return (
            <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-semibold font-mono bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30">
              <AlertTriangle className="h-3 w-3 text-amber-500" />
              Tier 2 Warden
            </span>
          )
        }

        return (
          <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-mono text-muted-foreground bg-muted/40 border border-border/40">
            <Zap className="h-2.5 w-2.5 text-muted-foreground" />
            Tier 1 Normal
          </span>
        )
      },
    },
    {
      accessorKey: "assignedToName",
      header: "Assigned Staff",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {row.original.assignedToName || "Unassigned"}
        </span>
      ),
    },
    {
      accessorKey: "createdAt",
      header: "Age / Created",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          {row.original.isAgeing ? (
            <span className="inline-flex items-center gap-1 font-mono text-xs font-semibold text-rose-600 dark:text-rose-400">
              <Clock className="h-3 w-3" /> {row.original.ageHours}h
            </span>
          ) : (
            <span className="text-xs text-muted-foreground font-mono">
              {formatRelativeTime(row.original.createdAt)}
            </span>
          )}
        </div>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <Button
          variant="ghost"
          size="sm"
          onClick={(e) => {
            e.stopPropagation()
            handleRowClick(row.original)
          }}
          className="text-xs text-muted-foreground hover:text-foreground gap-1"
        >
          Details
          <ExternalLink className="h-3 w-3" />
        </Button>
      ),
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Complaints Control Desk"
        description="Operational incident triage, institutional assignment, Proof-of-Fix OTP closure verification, and automated SLA Slingshot escalation."
        badge={
          <span className="text-xs font-mono text-muted-foreground">
            {complaints.length} Total Complaints
          </span>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              size="sm"
              onClick={handleEvaluateSlingshot}
              disabled={isEvaluating}
              className="h-8 text-xs gap-1.5 bg-gradient-to-r from-amber-600 via-orange-600 to-rose-600 hover:from-amber-700 hover:to-rose-700 text-white font-medium shadow-sm transition-all"
            >
              <Zap className={`h-3.5 w-3.5 ${isEvaluating ? "animate-spin" : ""}`} />
              {isEvaluating ? "Evaluating Slingshot..." : "Evaluate SLA Slingshot"}
            </Button>
          </div>
        }
      />

      {/* Proof-of-Fix & SLA Slingshot Executive Metrics Bar */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3.5">
        <div className="rounded-xl border border-emerald-500/30 bg-card p-4 space-y-1 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Proof-of-Fix Handshake</span>
            <span className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
              <ShieldCheck className="h-4 w-4" />
            </span>
          </div>
          <div className="text-xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            100% Locked
          </div>
          <p className="text-[11px] text-muted-foreground">
            2-Way Mutual OTP required for closure
          </p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Tier 1 Normal (Within SLA)</span>
            <span className="p-1.5 rounded-lg bg-blue-500/10 text-blue-600 dark:text-blue-400">
              <Clock className="h-4 w-4" />
            </span>
          </div>
          <div className="text-xl font-bold font-mono text-foreground">
            {slingshotData?.tier1Normal ?? 0}
          </div>
          <p className="text-[11px] text-muted-foreground">
            Active tickets &lt;24 hours resolution
          </p>
        </div>

        <div className="rounded-xl border border-amber-500/30 bg-card p-4 space-y-1 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Tier 2 Warden Alerts</span>
            <span className="p-1.5 rounded-lg bg-amber-500/10 text-amber-600 dark:text-amber-400">
              <AlertTriangle className="h-4 w-4" />
            </span>
          </div>
          <div className="text-xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {slingshotData?.tier2WardenAlert ?? 0}
          </div>
          <p className="text-[11px] text-muted-foreground">
            Breached 24h SLA • Warden notified
          </p>
        </div>

        <div className="rounded-xl border border-rose-500/30 bg-card p-4 space-y-1 relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-medium text-muted-foreground">Tier 3 Dean Slingshot</span>
            <span className="p-1.5 rounded-lg bg-rose-500/10 text-rose-600 dark:text-rose-400">
              <Flame className="h-4 w-4" />
            </span>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-xl font-bold font-mono text-rose-600 dark:text-rose-400">
              {slingshotData?.tier3DeanSlingshot ?? 0}
            </span>
            {(slingshotData?.totalVendorPenaltyAmount ?? 0) > 0 && (
              <span className="text-xs font-mono font-bold text-rose-500">
                (₹{slingshotData?.totalVendorPenaltyAmount} penalty)
              </span>
            )}
          </div>
          <p className="text-[11px] text-muted-foreground">
            Breached 48h SLA • ₹500 vendor deduction
          </p>
        </div>
      </div>

      <Tabs defaultValue="all" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="all" className="text-xs gap-1.5">
            <AlertCircle className="h-3.5 w-3.5" />
            Operational Queue ({complaints.length})
          </TabsTrigger>
          <TabsTrigger value="slingshot" className="text-xs gap-1.5">
            <Flame className="h-3.5 w-3.5 text-rose-500" />
            SLA Slingshot Violations ({slingshotData?.slingshotTickets?.length || 0})
          </TabsTrigger>
          <TabsTrigger value="recurring" className="text-xs gap-1.5">
            <Repeat className="h-3.5 w-3.5" />
            Recurring Clusters ({recurringClusters.length})
          </TabsTrigger>
        </TabsList>

        {/* ALL COMPLAINTS TAB */}
        <TabsContent value="all" className="space-y-4">
          <DataTable
            columns={columns}
            data={complaints}
            isLoading={isLoading}
            error={error}
            onRetry={refetch}
            searchPlaceholder="Search complaints by title, location or ID..."
            searchColumnId="title"
            onRowClick={handleRowClick}
            emptyTitle="No Complaints Found"
            emptyDescription="There are no active complaint tickets matching your selected status and priority filters."
            toolbarSlot={
              <div className="flex items-center gap-2 flex-wrap">
                {/* Status filter */}
                <Select value={statusParam} onValueChange={handleStatusFilterChange}>
                  <SelectTrigger className="w-32 h-8 text-xs bg-card">
                    <SelectValue placeholder="Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">All Statuses</SelectItem>
                    <SelectItem value="PENDING">Pending</SelectItem>
                    <SelectItem value="ASSIGNED">Assigned</SelectItem>
                    <SelectItem value="IN_PROGRESS">In Progress</SelectItem>
                    <SelectItem value="RESOLVED">Resolved</SelectItem>
                    <SelectItem value="CLOSED">Closed</SelectItem>
                    <SelectItem value="REOPENED">Reopened</SelectItem>
                    <SelectItem value="REJECTED">Rejected</SelectItem>
                  </SelectContent>
                </Select>

                {/* Priority filter */}
                <Select value={priorityParam} onValueChange={handlePriorityFilterChange}>
                  <SelectTrigger className="w-28 h-8 text-xs bg-card">
                    <SelectValue placeholder="Priority" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">All Priority</SelectItem>
                    <SelectItem value="URGENT">Urgent</SelectItem>
                    <SelectItem value="HIGH">High</SelectItem>
                    <SelectItem value="MEDIUM">Medium</SelectItem>
                    <SelectItem value="LOW">Low</SelectItem>
                  </SelectContent>
                </Select>

                {/* Ageing toggle */}
                <Button
                  variant={ageingParam ? "destructive" : "outline"}
                  size="sm"
                  onClick={toggleAgeingFilter}
                  className="h-8 text-xs gap-1"
                >
                  <Clock className="h-3.5 w-3.5" />
                  Ageing (&gt;48h)
                </Button>
              </div>
            }
          />
        </TabsContent>

        {/* SLA SLINGSHOT TAB */}
        <TabsContent value="slingshot" className="space-y-4">
          <div className="rounded-xl border border-rose-500/20 bg-card p-5 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold tracking-tight text-foreground flex items-center gap-2">
                  <Flame className="h-4 w-4 text-rose-500" />
                  SLA Slingshot Escalated Queue
                </h2>
                <p className="text-xs text-muted-foreground">
                  Tickets that breached standard resolution windows, escalated to Wardens or Deans with financial penalty flags.
                </p>
              </div>
              <Button
                size="sm"
                variant="outline"
                onClick={handleEvaluateSlingshot}
                disabled={isEvaluating}
                className="h-7 text-xs gap-1"
              >
                <RotateCw className={`h-3 w-3 ${isEvaluating ? "animate-spin" : ""}`} />
                Re-evaluate SLA
              </Button>
            </div>

            {isSlingshotLoading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="h-16 rounded-lg bg-muted/40 animate-pulse" />
                ))}
              </div>
            ) : (slingshotData?.slingshotTickets?.length || 0) > 0 ? (
              <div className="divide-y divide-border/60">
                {slingshotData?.slingshotTickets.map((ticket) => (
                  <div
                    key={ticket.id}
                    onClick={() => handleRowClick(ticket)}
                    className="py-3.5 flex items-center justify-between gap-4 text-xs hover:bg-muted/20 px-2 rounded-lg cursor-pointer transition-colors"
                  >
                    <div className="space-y-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-mono text-xs font-semibold text-foreground">
                          #{ticket.id.slice(0, 8)}
                        </span>
                        <span className="font-semibold text-foreground text-xs truncate max-w-xs">
                          {ticket.title}
                        </span>
                        <Badge variant="outline" className="text-[10px] font-mono">
                          {ticket.category}
                        </Badge>
                        {ticket.escalationLevel === 3 ? (
                          <Badge variant="destructive" className="text-[10px] gap-1 animate-pulse">
                            <Flame className="h-3 w-3" /> Tier 3 Dean
                          </Badge>
                        ) : (
                          <Badge variant="warning" className="text-[10px] gap-1">
                            <AlertTriangle className="h-3 w-3" /> Tier 2 Warden
                          </Badge>
                        )}
                        {ticket.vendorPenaltyFlag && (
                          <span className="text-[11px] font-mono font-bold text-rose-500">
                            Penalty: -₹{ticket.vendorPenaltyAmount || 500}
                          </span>
                        )}
                      </div>
                      <p className="text-muted-foreground text-[11px]">
                        Location: {ticket.location || "General Campus"} • Assigned: {ticket.assignedToName || "Unassigned"} • Open for {ticket.ageHours}h
                      </p>
                    </div>

                    <div className="text-right shrink-0">
                      <Button variant="ghost" size="sm" className="h-7 text-xs gap-1">
                        View Ticket
                        <ExternalLink className="h-3 w-3" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-muted-foreground py-8 text-center">
                All active tickets are currently performing within acceptable SLA limits! No escalations triggered.
              </p>
            )}
          </div>
        </TabsContent>

        {/* RECURRING CLUSTERS TAB */}
        <TabsContent value="recurring" className="space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-5 space-y-4">
            <div>
              <h2 className="text-sm font-semibold tracking-tight text-foreground flex items-center gap-2">
                <Repeat className="h-4 w-4 text-primary" />
                Recurring Complaint Patterns & Hotspots
              </h2>
              <p className="text-xs text-muted-foreground">
                Automated clustering of repeated complaints at the same campus facility or room
              </p>
            </div>

            {isRecurringLoading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="h-16 rounded-lg bg-muted/40 animate-pulse" />
                ))}
              </div>
            ) : recurringClusters.length > 0 ? (
              <div className="divide-y divide-border/60">
                {recurringClusters.map((cluster) => (
                  <div
                    key={cluster.recurrenceId}
                    className="py-3.5 flex items-center justify-between gap-4 text-xs hover:bg-muted/20 px-2 rounded-lg"
                  >
                    <div className="space-y-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-foreground text-xs">
                          {cluster.location || "General Location"}
                        </span>
                        <Badge variant="outline" className="font-mono text-[10px]">
                          {cluster.category}
                        </Badge>
                        <Badge
                          variant={cluster.recurrenceStatus === "ACTIVE" ? "destructive" : "success"}
                          className="text-[10px]"
                        >
                          {cluster.recurrenceStatus}
                        </Badge>
                      </div>
                      <p className="text-muted-foreground text-[11px]">
                        Latest incident logged {formatRelativeTime(cluster.latestComplaintAt)} • Avg resolution: {cluster.averageResolutionHours}h
                      </p>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="text-base font-bold font-mono text-foreground">
                        {cluster.complaintCount}
                      </span>
                      <p className="text-[10px] text-muted-foreground">Repeat Incidents</p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-muted-foreground py-8 text-center">
                No recurring complaint clusters detected across campus facilities.
              </p>
            )}
          </div>
        </TabsContent>
      </Tabs>

      {/* Complaint Detail Sheet */}
      <ComplaintDetailSheet
        complaintId={selectedComplaintId}
        open={sheetOpen}
        onOpenChange={setSheetOpen}
      />
    </div>
  )
}

import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import {
  AlertCircle,
  AlertTriangle,
  Building2,
  CalendarCheck,
  CheckCircle2,
  Clock,
  ExternalLink,
  Hourglass,
  Receipt,
  Shield,
  UserCheck,
  Users,
  Activity,
  ArrowUpRight,
} from "lucide-react"
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip as RechartsTooltip,
  ResponsiveContainer,
  Cell,
} from "recharts"
import { PageHeader } from "@/components/ui/page-header"
import { KpiCard } from "./components/kpi-card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { EmptyState } from "@/components/ui/empty-state"
import { ErrorState } from "@/components/ui/error-state"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { dashboardApi } from "./api/dashboard-api"
import { formatCurrency, formatRelativeTime } from "@/lib/utils"

export function DashboardPage() {
  const navigate = useNavigate()

  const {
    data: summary,
    isLoading: isSummaryLoading,
    error: summaryError,
    refetch: refetchSummary,
  } = useQuery({
    queryKey: ["admin", "dashboard", "summary"],
    queryFn: dashboardApi.getSummary,
  })

  const { data: ageing, isLoading: isAgeingLoading } = useQuery({
    queryKey: ["admin", "complaints", "ageing"],
    queryFn: dashboardApi.getAgeingComplaints,
  })

  const { data: categories, isLoading: isCategoriesLoading } = useQuery({
    queryKey: ["admin", "complaints", "categories"],
    queryFn: dashboardApi.getCategories,
  })

  const { data: workload, isLoading: isWorkloadLoading } = useQuery({
    queryKey: ["admin", "complaints", "workload"],
    queryFn: dashboardApi.getWorkload,
  })

  const { data: hostelKpis } = useQuery({
    queryKey: ["admin", "hostel", "kpis"],
    queryFn: dashboardApi.getHostelKpis,
  })

  const { data: feeKpis } = useQuery({
    queryKey: ["admin", "fees", "kpis"],
    queryFn: dashboardApi.getFeeKpis,
  })

  const { data: visitorKpis } = useQuery({
    queryKey: ["admin", "visitors", "kpis"],
    queryFn: dashboardApi.getVisitorKpis,
  })

  if (summaryError) {
    return (
      <div className="py-12">
        <ErrorState
          status={(summaryError as any)?.status}
          message={(summaryError as any)?.message}
          onRetry={refetchSummary}
        />
      </div>
    )
  }

  // Bar colors with calm institutional palette
  const CHART_COLORS = ["#1e3a8a", "#0284c7", "#475569", "#64748b", "#94a3b8"]

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <PageHeader
        title="Command Center"
        description="Institutional operational overview, pending escalations, and cross-domain campus telemetry."
        badge={
          <StatusIndicator
            status="active"
            label="Live Operational State"
            pulse
          />
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => navigate("/complaints")}
              className="text-xs"
            >
              Complaints Desk
            </Button>
            <Button
              size="sm"
              onClick={() => navigate("/notices")}
              className="text-xs"
            >
              Publish Notice
            </Button>
          </div>
        }
      />

      {/* Top Banner: Immediate Attention Bar */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <KpiCard
          title="Active Complaints"
          value={
            isSummaryLoading ? (
              <Skeleton className="h-7 w-12" />
            ) : (
              (summary?.pendingComplaints || 0) +
              (summary?.assignedComplaints || 0) +
              (summary?.inProgressComplaints || 0)
            )
          }
          subValue={`${summary?.pendingComplaints || 0} unassigned pending`}
          icon={AlertCircle}
          alert={(summary?.pendingComplaints || 0) > 0}
          onClick={() => navigate("/complaints?status=PENDING")}
        />

        <KpiCard
          title="Ageing Issues (>48h)"
          value={
            isSummaryLoading ? (
              <Skeleton className="h-7 w-12" />
            ) : (
              summary?.ageingComplaints || 0
            )
          }
          subValue="Exceeding resolution SLA"
          icon={Clock}
          alert={(summary?.ageingComplaints || 0) > 0}
          onClick={() => navigate("/complaints?ageing=true")}
        />

        <KpiCard
          title="Visitors Inside Campus"
          value={visitorKpis?.insideCampusNow ?? "—"}
          subValue={`${visitorKpis?.pendingApprovals ?? 0} pending gate approval`}
          icon={UserCheck}
          alert={(visitorKpis?.pendingApprovals ?? 0) > 0}
          onClick={() => navigate("/visitors")}
        />

        <KpiCard
          title="Outstanding Dues"
          value={
            feeKpis?.totalOutstanding != null
              ? formatCurrency(feeKpis.totalOutstanding)
              : "—"
          }
          subValue={`${feeKpis?.overdueCount ?? 0} overdue fee accounts`}
          icon={Receipt}
          alert={(feeKpis?.overdueCount ?? 0) > 0}
          onClick={() => navigate("/fees?status=DUE")}
        />
      </div>

      {/* Middle Section: Urgent Action Queue & Workload */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Ageing / Escalated Items */}
        <div className="lg:col-span-2 space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <h2 className="text-sm font-semibold tracking-tight text-foreground flex items-center gap-2">
                  <Hourglass className="h-4 w-4 text-amber-500" />
                  Ageing Operational Escalations
                </h2>
                <p className="text-xs text-muted-foreground">
                  Complaints requiring immediate triage or staff re-assignment
                </p>
              </div>
              <Button
                variant="ghost"
                size="sm"
                className="text-xs text-muted-foreground hover:text-foreground"
                onClick={() => navigate("/complaints?ageing=true")}
              >
                View all ageing
                <ArrowUpRight className="h-3 w-3 ml-1" />
              </Button>
            </div>

            {isAgeingLoading ? (
              <div className="space-y-2">
                {Array.from({ length: 3 }).map((_, i) => (
                  <Skeleton key={i} className="h-14 w-full" />
                ))}
              </div>
            ) : ageing && ageing.length > 0 ? (
              <div className="divide-y divide-border/60">
                {ageing.slice(0, 5).map((item) => (
                  <div
                    key={item.id}
                    onClick={() => navigate(`/complaints/${item.id}`)}
                    className="py-3 flex items-start justify-between gap-3 hover:bg-muted/30 px-2 rounded-lg cursor-pointer transition-colors group"
                  >
                    <div className="space-y-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-semibold text-xs text-foreground group-hover:text-primary transition-colors">
                          {item.title}
                        </span>
                        <Badge
                          variant={
                            item.priority === "URGENT"
                              ? "destructive"
                              : item.priority === "HIGH"
                              ? "warning"
                              : "secondary"
                          }
                        >
                          {item.priority}
                        </Badge>
                        <span className="text-[11px] text-muted-foreground font-mono">
                          #{item.complaintId.slice(0, 8)}
                        </span>
                      </div>
                      <div className="flex items-center gap-2 text-[11px] text-muted-foreground">
                        <span>{item.category}</span>
                        <span>•</span>
                        <span>
                          Assigned: {item.assignedToName || "Unassigned"}
                        </span>
                      </div>
                    </div>

                    <div className="text-right shrink-0">
                      <span className="inline-flex items-center gap-1 text-xs font-semibold text-rose-600 dark:text-rose-400 font-mono">
                        <Clock className="h-3 w-3" />
                        {item.ageHours}h age
                      </span>
                      <p className="text-[10px] text-muted-foreground">
                        {formatRelativeTime(item.createdAt)}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <EmptyState
                icon={CheckCircle2}
                title="No Ageing Escalations"
                description="All active operational complaints are within expected SLA thresholds."
                compact
              />
            )}
          </div>

          {/* Operational Domain Metrics Overview */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Hostel Facility Overview */}
            <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Building2 className="h-3.5 w-3.5 text-muted-foreground" />
                  Hostel Operations
                </span>
                <span className="text-xs font-mono text-muted-foreground">
                  {hostelKpis?.occupancyRate ?? "92.5"}% Occupancy
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 pt-1 text-xs">
                <div className="rounded-lg bg-muted/40 p-2.5">
                  <p className="text-muted-foreground text-[11px]">Residents</p>
                  <p className="text-base font-semibold text-foreground">
                    {hostelKpis?.totalResidents ?? "—"}
                  </p>
                </div>
                <div className="rounded-lg bg-muted/40 p-2.5">
                  <p className="text-muted-foreground text-[11px]">Pending Requests</p>
                  <p className="text-base font-semibold text-foreground">
                    {hostelKpis?.pendingRequests ?? "—"}
                  </p>
                </div>
              </div>
            </div>

            {/* Turnaround Resolution SLA */}
            <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Activity className="h-3.5 w-3.5 text-muted-foreground" />
                  Resolution SLA
                </span>
                <span className="text-xs font-mono text-emerald-600 dark:text-emerald-400">
                  Target: &lt; 24h
                </span>
              </div>
              <div className="grid grid-cols-2 gap-2 pt-1 text-xs">
                <div className="rounded-lg bg-muted/40 p-2.5">
                  <p className="text-muted-foreground text-[11px]">Avg Resolution</p>
                  <p className="text-base font-semibold text-foreground">
                    {summary?.averageResolutionHours ?? 0}h
                  </p>
                </div>
                <div className="rounded-lg bg-muted/40 p-2.5">
                  <p className="text-muted-foreground text-[11px]">Resolved Total</p>
                  <p className="text-base font-semibold text-foreground">
                    {(summary?.resolvedComplaints || 0) +
                      (summary?.closedComplaints || 0)}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Category Distribution Chart & Staff Workload */}
        <div className="space-y-4">
          {/* Complaints by Category Chart */}
          <div className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-4">
            <div>
              <h2 className="text-sm font-semibold tracking-tight text-foreground">
                Distribution by Domain
              </h2>
              <p className="text-xs text-muted-foreground">
                Complaint concentration across campus sectors
              </p>
            </div>

            {isCategoriesLoading ? (
              <Skeleton className="h-44 w-full" />
            ) : categories && categories.length > 0 ? (
              <div className="h-44 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart
                    data={categories.slice(0, 5)}
                    margin={{ top: 10, right: 10, left: -20, bottom: 0 }}
                  >
                    <XAxis
                      dataKey="category"
                      stroke="#888888"
                      fontSize={10}
                      tickLine={false}
                      axisLine={false}
                    />
                    <YAxis
                      stroke="#888888"
                      fontSize={10}
                      tickLine={false}
                      axisLine={false}
                      allowDecimals={false}
                    />
                    <RechartsTooltip
                      contentStyle={{
                        backgroundColor: "hsl(var(--card))",
                        borderColor: "hsl(var(--border))",
                        borderRadius: "8px",
                        fontSize: "11px",
                      }}
                    />
                    <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                      {categories.slice(0, 5).map((_, index) => (
                        <Cell
                          key={`cell-${index}`}
                          fill={CHART_COLORS[index % CHART_COLORS.length]}
                        />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <div className="py-8 text-center text-xs text-muted-foreground">
                No categorical complaint data available
              </div>
            )}
          </div>

          {/* Active Staff Workload Distribution */}
          <div className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-3">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold tracking-tight text-foreground">
                  Staff Workload
                </h2>
                <p className="text-xs text-muted-foreground">
                  Active tickets assigned to institutional personnel
                </p>
              </div>
              <Users className="h-4 w-4 text-muted-foreground" />
            </div>

            {isWorkloadLoading ? (
              <div className="space-y-2">
                {Array.from({ length: 3 }).map((_, i) => (
                  <Skeleton key={i} className="h-10 w-full" />
                ))}
              </div>
            ) : workload && workload.length > 0 ? (
              <div className="space-y-2 divide-y divide-border/40">
                {workload.slice(0, 4).map((staff) => (
                  <div
                    key={staff.staffId}
                    className="pt-2 first:pt-0 flex items-center justify-between text-xs"
                  >
                    <div className="min-w-0">
                      <p className="font-medium text-foreground truncate">
                        {staff.staffName}
                      </p>
                      <p className="text-[10px] text-muted-foreground capitalize">
                        {staff.staffRole}
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="font-semibold text-foreground font-mono">
                        {staff.totalActive} active
                      </span>
                      <p className="text-[10px] text-muted-foreground">
                        {staff.resolvedCount} resolved
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="py-6 text-center text-xs text-muted-foreground">
                No active staff workload assignments
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}

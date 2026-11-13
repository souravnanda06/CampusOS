import { useQuery } from "@tanstack/react-query"
import { useNavigate } from "react-router-dom"
import {
  AlertCircle,
  Building2,
  CalendarClock,
  CheckCircle2,
  Clock,
  Hourglass,
  Radio,
  Receipt,
  Repeat,
  UserCheck,
  Users,
  Activity,
  ArrowUpRight,
  KeyRound,
  Megaphone,
  Utensils,
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
import { complaintsApi } from "@/features/complaints/api/complaints-api"
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

  const { data: recurringClusters = [] } = useQuery({
    queryKey: ["admin", "complaints", "recurring"],
    queryFn: complaintsApi.getRecurringClusters,
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

  const { data: wardenSummary } = useQuery({
    queryKey: ["warden", "summary"],
    queryFn: dashboardApi.getWardenSummary,
  })

  const { data: activeSessions = [] } = useQuery({
    queryKey: ["attendance", "sessions", "active"],
    queryFn: dashboardApi.getActiveSessions,
  })

  if (summaryError) {
    return (
      <div className="py-12">
        <ErrorState
          status={(summaryError as { status?: number })?.status}
          message={(summaryError as { message?: string })?.message}
          onRetry={refetchSummary}
        />
      </div>
    )
  }

  const CHART_COLORS = ["#1e3a8a", "#0284c7", "#475569", "#64748b", "#94a3b8"]

  const totalComplaints = summary?.totalComplaints || 0
  const totalResolved = (summary?.resolvedComplaints || 0) + (summary?.closedComplaints || 0)
  const resolutionRate = totalComplaints > 0 ? Math.round((totalResolved / totalComplaints) * 100) : 0
  const activeRecurring = recurringClusters.filter((r) => r.recurrenceStatus === "ACTIVE")

  return (
    <div className="space-y-6">
      <PageHeader
        title="Command Center"
        description="Institutional operational overview, SLA escalations, recurring hotspot intelligence, and cross-domain campus control."
        badge={
          <StatusIndicator
            status="active"
            label="Live Operational State"
            pulse
          />
        }
        actions={
          <div className="flex items-center gap-2 flex-wrap">
            {(summary?.pendingStudentApprovals || 0) > 0 && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => navigate("/people?tab=pending")}
                className="text-xs border-amber-500/40 bg-amber-500/10 text-amber-700 dark:text-amber-300 hover:bg-amber-500/20 gap-1.5"
              >
                <UserCheck className="h-3.5 w-3.5" />
                {summary?.pendingStudentApprovals} Student Approval
                {(summary?.pendingStudentApprovals || 0) > 1 ? "s" : ""}
              </Button>
            )}
            <Button
              variant="outline"
              size="sm"
              onClick={() => navigate("/mesh")}
              className="text-xs gap-1.5 border-rose-500/30 text-rose-600 dark:text-rose-400 hover:bg-rose-500/10"
            >
              <Radio className="h-3.5 w-3.5" />
              Mesh Flare
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

      {(summary?.pendingStudentApprovals || 0) > 0 && (
        <div
          onClick={() => navigate("/people?tab=pending")}
          className="cursor-pointer rounded-xl border border-amber-500/30 bg-amber-500/5 px-4 py-3 flex items-center justify-between gap-3 hover:bg-amber-500/10 transition-colors"
        >
          <div className="flex items-center gap-3">
            <div className="h-8 w-8 rounded-lg bg-amber-500/15 flex items-center justify-center text-amber-600 dark:text-amber-400">
              <UserCheck className="h-4 w-4" />
            </div>
            <div>
              <p className="text-xs font-semibold text-foreground">
                {summary?.pendingStudentApprovals} student registration
                {(summary?.pendingStudentApprovals || 0) > 1 ? "s" : ""} awaiting verification
              </p>
              <p className="text-[11px] text-muted-foreground">
                Review uploaded registration photos and approve accounts to allow sign in.
              </p>
            </div>
          </div>
          <Button variant="outline" size="sm" className="text-xs shrink-0 gap-1">
            Review Queue
            <ArrowUpRight className="h-3.5 w-3.5" />
          </Button>
        </div>
      )}

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
          subValue={`${summary?.pendingComplaints || 0} unassigned • ${summary?.reopenedComplaints || 0} reopened`}
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
          subValue={`${activeRecurring.length} active recurring clusters`}
          icon={Clock}
          alert={(summary?.ageingComplaints || 0) > 0}
          onClick={() => navigate("/complaints?ageing=true")}
        />

        <KpiCard
          title="Leaves & Gate Passes"
          value={wardenSummary?.pendingRequests ?? "—"}
          subValue={`${wardenSummary?.activeGatePasses ?? 0} active passes • ${visitorKpis?.insideCampusNow ?? 0} visitors inside`}
          icon={CalendarClock}
          alert={(wardenSummary?.pendingRequests ?? 0) > 0}
          onClick={() => navigate("/leaves")}
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

      {/* Quick Actions Strip (mirrors Flutter AdminHomeContent Quick Actions) */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-2.5">
        {[
          { label: "Complaints", sub: "Triage & SLA", icon: AlertCircle, path: "/complaints" },
          { label: "Leave Queue", sub: `${wardenSummary?.pendingRequests ?? 0} pending`, icon: CalendarClock, path: "/leaves" },
          { label: "Attendance", sub: `${activeSessions.length} live sessions`, icon: Activity, path: "/attendance" },
          { label: "Notices", sub: "Broadcasts", icon: Megaphone, path: "/notices" },
          { label: "Mess Dining", sub: "Menus & ratings", icon: Utensils, path: "/mess" },
          { label: "Passport CA", sub: "Trust & verify", icon: KeyRound, path: "/passport" },
        ].map((q) => {
          const Icon = q.icon
          return (
            <button
              key={q.path}
              type="button"
              onClick={() => navigate(q.path)}
              className="rounded-xl border border-border/80 bg-card px-3.5 py-2.5 text-left hover:border-primary/40 hover:bg-accent/30 transition-colors flex items-center gap-2.5"
            >
              <div className="h-8 w-8 rounded-lg bg-primary/10 text-primary flex items-center justify-center shrink-0">
                <Icon className="h-4 w-4" />
              </div>
              <div className="min-w-0">
                <p className="text-xs font-semibold text-foreground truncate">{q.label}</p>
                <p className="text-[10px] text-muted-foreground truncate">{q.sub}</p>
              </div>
            </button>
          )
        })}
      </div>

      {/* Middle Section: Urgent Action Queue & Workload */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
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
                        <span>Assigned: {item.assignedToName || "Unassigned"}</span>
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
            <div
              onClick={() => navigate("/hostel")}
              className="cursor-pointer rounded-xl border border-border/80 bg-card p-4 space-y-2 hover:border-primary/40 transition-colors"
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Building2 className="h-3.5 w-3.5 text-muted-foreground" />
                  Hostel Operations
                </span>
                <span className="text-xs font-mono text-muted-foreground">
                  {hostelKpis?.damagedAssets ?? 0} Damaged Assets
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

            <div
              onClick={() => navigate("/complaints?tab=recurring")}
              className="cursor-pointer rounded-xl border border-border/80 bg-card p-4 space-y-2 hover:border-primary/40 transition-colors"
            >
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Activity className="h-3.5 w-3.5 text-muted-foreground" />
                  Resolution Performance
                </span>
                <span className="text-xs font-mono text-emerald-600 dark:text-emerald-400">
                  {resolutionRate}% Resolved
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
                  <p className="text-muted-foreground text-[11px]">Recurring Hotspots</p>
                  <p className="text-base font-semibold text-foreground flex items-center gap-1">
                    <Repeat className="h-3.5 w-3.5 text-primary" />
                    {activeRecurring.length}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Right Col: Category Distribution Chart & Staff Workload */}
        <div className="space-y-4">
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
                      <p className="font-medium text-foreground truncate">{staff.staffName}</p>
                      <p className="text-[10px] text-muted-foreground capitalize">{staff.staffRole}</p>
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

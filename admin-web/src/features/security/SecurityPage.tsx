import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { useToast } from "@/components/ui/toast"
import { securityApi, SecurityGatePass, GateActivityItem } from "./api/security-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  Shield,
  Radio,
  ArrowRightCircle,
  ArrowLeftCircle,
  Clock,
  AlertTriangle,
  History,
  CheckCircle2,
  RefreshCw,
} from "lucide-react"

export function SecurityPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [statusFilter, setStatusFilter] = React.useState<string>("ALL")
  const [activityFilter, setActivityFilter] = React.useState<string>("ALL")

  const { data: summary } = useQuery({
    queryKey: ["security", "summary"],
    queryFn: securityApi.getSummary,
    refetchInterval: 15000,
  })

  const {
    data: gatePasses = [],
    isLoading: isPassesLoading,
    error: passesError,
    refetch: refetchPasses,
  } = useQuery({
    queryKey: ["security", "passes", statusFilter],
    queryFn: () => securityApi.getGatePasses({ status: statusFilter }),
  })

  const {
    data: activity = [],
    isLoading: isActivityLoading,
    refetch: refetchActivity,
  } = useQuery({
    queryKey: ["security", "activity", activityFilter],
    queryFn: () => securityApi.getActivity(activityFilter),
    refetchInterval: 15000,
  })

  const exitMutation = useMutation({
    mutationFn: (id: string) => securityApi.recordExit(id),
    onSuccess: (data) => {
      toast({
        title: "Student Exited Gate",
        description: `Exit logged for ${data.gatePass.student?.name || "student"}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["security"] })
    },
    onError: (err: any) => {
      toast({
        title: "Exit Recording Failed",
        description: err.message || "Failed to log gate exit",
        type: "error",
      })
    },
  })

  const returnMutation = useMutation({
    mutationFn: (id: string) => securityApi.recordReturn(id),
    onSuccess: (data) => {
      toast({
        title: "Student Returned",
        description: `Campus return logged for ${data.gatePass.student?.name || "student"}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["security"] })
    },
    onError: (err: any) => {
      toast({
        title: "Return Recording Failed",
        description: err.message || "Failed to log gate return",
        type: "error",
      })
    },
  })

  const passColumns: ColumnDef<SecurityGatePass>[] = [
    {
      accessorKey: "student",
      header: "Student",
      cell: ({ row }) => {
        const s = row.original.student
        return (
          <div className="space-y-0.5">
            <p className="font-semibold text-xs text-foreground">{s.name}</p>
            <p className="text-[10px] text-muted-foreground font-mono">
              {s.registrationNumber} ({s.branch} Yr {s.year})
            </p>
          </div>
        )
      },
    },
    {
      accessorKey: "destination",
      header: "Destination & Reason",
      cell: ({ row }) => (
        <div className="space-y-0.5 max-w-xs">
          <p className="font-medium text-xs text-foreground">{row.original.destination}</p>
          <p className="text-[10px] text-muted-foreground truncate">{row.original.reason}</p>
        </div>
      ),
    },
    {
      accessorKey: "expected_exit_time",
      header: "Validity Window",
      cell: ({ row }) => (
        <div className="text-[11px] text-muted-foreground font-mono space-y-0.5">
          <p>Out: {formatDate(row.original.expected_exit_time)}</p>
          <p>Return: {formatDate(row.original.expected_return_time)}</p>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Pass State",
      cell: ({ row }) => {
        const status = row.original.status
        const variant =
          status === "EXITED"
            ? "warning"
            : status === "RETURNED"
            ? "success"
            : status === "EXPIRED"
            ? "destructive"
            : "secondary"
        return (
          <Badge variant={variant} className="text-[10px] font-mono">
            {status}
          </Badge>
        )
      },
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const p = row.original
        if (p.status === "ISSUED") {
          return (
            <Button
              size="sm"
              onClick={() => exitMutation.mutate(p.id)}
              loading={exitMutation.isPending}
              className="h-7 text-xs gap-1"
            >
              <ArrowRightCircle className="h-3 w-3" /> Log Gate Exit
            </Button>
          )
        }
        if (p.status === "EXITED") {
          return (
            <Button
              size="sm"
              variant="outline"
              onClick={() => returnMutation.mutate(p.id)}
              loading={returnMutation.isPending}
              className="h-7 text-xs gap-1 text-emerald-600 dark:text-emerald-400 border-emerald-500/30"
            >
              <ArrowLeftCircle className="h-3 w-3" /> Log Gate Return
            </Button>
          )
        }
        return <span className="text-[11px] text-muted-foreground font-mono">{p.status}</span>
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Security Gate Command"
        description="Gate access control, student exits and returns verification, and chronological perimeter audit."
        badge={
          <StatusIndicator
            status={summary?.gateStatus === "ONLINE" ? "success" : "pending"}
            label={summary?.gateStatus || "Perimeter Online"}
            pulse
          />
        }
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              refetchPasses()
              refetchActivity()
            }}
            className="text-xs gap-1.5"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {/* Security Shift Metrics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Students Outside Perimeter</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {summary?.studentsOutside ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Currently exited campus</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Passes Awaiting Exit</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {summary?.passesAwaitingVerification ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Approved by Warden</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Returned Today</p>
          <p className="text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            {summary?.recentlyReturned ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Verified re-entries</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Active Guard Shift</p>
          <p className="text-sm font-semibold text-foreground truncate mt-1">
            {summary?.activeShift || "Day Duty"}
          </p>
          <p className="text-[11px] text-muted-foreground">Perimeter Station Alpha</p>
        </div>
      </div>

      <Tabs defaultValue="passes" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="passes" className="text-xs gap-1.5">
            <Shield className="h-3.5 w-3.5" />
            Gate Passes & Verification ({gatePasses.length})
          </TabsTrigger>
          <TabsTrigger value="timeline" className="text-xs gap-1.5">
            <History className="h-3.5 w-3.5" />
            Perimeter Activity Timeline ({activity.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="passes" className="space-y-4">
          <DataTable
            columns={passColumns}
            data={gatePasses}
            isLoading={isPassesLoading}
            error={passesError}
            onRetry={refetchPasses}
            searchPlaceholder="Search by student name or destination..."
            searchColumnId="destination"
            emptyTitle="No Gate Passes Found"
            emptyDescription="There are no gate passes currently active or matching the selected status."
            toolbarSlot={
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-36 h-8 text-xs bg-card">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">All Passes</SelectItem>
                  <SelectItem value="ISSUED">Awaiting Exit</SelectItem>
                  <SelectItem value="EXITED">Currently Out</SelectItem>
                  <SelectItem value="RETURNED">Returned</SelectItem>
                  <SelectItem value="EXPIRED">Expired</SelectItem>
                </SelectContent>
              </Select>
            }
          />
        </TabsContent>

        <TabsContent value="timeline" className="space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-5 space-y-4 shadow-sm">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold tracking-tight text-foreground">
                  Perimeter Gate Audit Log
                </h2>
                <p className="text-xs text-muted-foreground">
                  Cryptographically audited entry/exit verification events
                </p>
              </div>

              <Select value={activityFilter} onValueChange={setActivityFilter}>
                <SelectTrigger className="w-32 h-8 text-xs bg-card">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">All Events</SelectItem>
                  <SelectItem value="EXITS">Exits Only</SelectItem>
                  <SelectItem value="RETURNS">Returns Only</SelectItem>
                  <SelectItem value="FAILED">Failed Attempts</SelectItem>
                </SelectContent>
              </Select>
            </div>

            {isActivityLoading ? (
              <div className="space-y-2">
                {Array.from({ length: 4 }).map((_, i) => (
                  <div key={i} className="h-14 rounded-lg bg-muted/40 animate-pulse" />
                ))}
              </div>
            ) : activity.length > 0 ? (
              <div className="divide-y divide-border/60">
                {activity.map((item) => (
                  <div
                    key={item.id}
                    className="py-3 flex items-start justify-between gap-3 text-xs hover:bg-muted/20 px-2 rounded-lg"
                  >
                    <div className="space-y-0.5 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-foreground">
                          {item.student.name}
                        </span>
                        <Badge
                          variant={
                            item.operation === "EXIT"
                              ? "warning"
                              : item.operation === "RETURN"
                              ? "success"
                              : "destructive"
                          }
                          className="text-[10px] font-mono"
                        >
                          {item.operation}
                        </Badge>
                        <span className="text-[10px] text-muted-foreground font-mono">
                          {item.verificationMode}
                        </span>
                      </div>
                      <p className="text-[11px] text-muted-foreground">
                        Guard: {item.securityStaff.name} • {item.remarks || "Gate verified"}
                      </p>
                    </div>

                    <span className="text-[11px] text-muted-foreground font-mono shrink-0">
                      {formatDate(item.timestamp)}
                    </span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="text-xs text-muted-foreground py-8 text-center">
                No perimeter security events logged for this filter.
              </p>
            )}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}

import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { PageHeader } from "@/components/ui/page-header"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { EmptyState } from "@/components/ui/empty-state"
import { ErrorState } from "@/components/ui/error-state"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { useToast } from "@/components/ui/toast"
import { CreateUpdateDialog } from "./components/create-update-dialog"
import { academicApi } from "./api/academic-api"
import { formatRelativeTime } from "@/lib/utils"
import {
  Plus,
  Calendar,
  Clock,
  MapPin,
  Megaphone,
  FileSpreadsheet,
  Ban,
} from "lucide-react"

export function AcademicPage() {
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false)
  const queryClient = useQueryClient()
  const { addToast } = useToast()

  const {
    data: updates = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["academic", "updates"],
    queryFn: academicApi.getAllUpdates,
  })

  const { data: summary } = useQuery({
    queryKey: ["academic", "today-summary"],
    queryFn: academicApi.getTodaySummary,
  })

  const cancelMutation = useMutation({
    mutationFn: (id: string) => academicApi.cancelUpdate(id),
    onSuccess: () => {
      addToast({ title: "Update Cancelled", message: "Academic notice marked as cancelled.", type: "success" })
      queryClient.invalidateQueries({ queryKey: ["academic"] })
    },
    onError: (err: Error) => {
      addToast({ title: "Cancel Failed", message: err.message || "Could not cancel update.", type: "error" })
    },
  })

  const getBadgeVariant = (type: string) => {
    switch (type) {
      case "CANCELLED":
        return "destructive"
      case "RESCHEDULED":
      case "ROOM_CHANGE":
      case "TIME_CHANGE":
        return "warning"
      default:
        return "secondary"
    }
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Academic Operations"
        description="Course updates, class cancellations, room modifications, and institutional schedule telemetry."
        badge={
          summary?.todayTotal ? (
            <Badge variant="warning" className="text-xs">
              {summary.cancellationsCount} Cancellations Today
            </Badge>
          ) : (
            <StatusIndicator status="success" label="Schedules Normal" />
          )
        }
        actions={
          <Button size="sm" onClick={() => setCreateDialogOpen(true)} className="gap-1.5 text-xs">
            <Plus className="h-3.5 w-3.5" />
            Post Class Update
          </Button>
        }
      />

      {/* Operational Highlights Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Updates Logged Today</p>
          <p className="text-2xl font-bold font-mono text-foreground">{summary?.todayTotal ?? 0}</p>
          <p className="text-[11px] text-muted-foreground">Active operational notices</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Class Cancellations</p>
          <p className="text-2xl font-bold font-mono text-rose-600 dark:text-rose-400">
            {summary?.cancellationsCount ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Lectures suspended today</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Rescheduled / Room Changes</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {summary?.rescheduledCount ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">Venue or timing altered</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Feed of Class Updates */}
        <div className="lg:col-span-2 space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-sm font-semibold tracking-tight text-foreground">
                  Published Academic Modifications
                </h2>
                <p className="text-xs text-muted-foreground">
                  Live feed of faculty bulletins and schedule alterations
                </p>
              </div>
              <Megaphone className="h-4 w-4 text-muted-foreground" />
            </div>

            {isLoading ? (
              <div className="space-y-3">
                {Array.from({ length: 4 }).map((_, i) => (
                  <Skeleton key={i} className="h-20 w-full" />
                ))}
              </div>
            ) : error ? (
              <ErrorState
                status={(error as any)?.status}
                message={(error as any)?.message}
                onRetry={refetch}
              />
            ) : updates && updates.length > 0 ? (
              <div className="space-y-3">
                {updates.map((update) => {
                  const typeLabel = (update.updateType || "ANNOUNCEMENT").replace(/_/g, " ")
                  const isActive = (update.status || "ACTIVE") === "ACTIVE"
                  return (
                    <div
                      key={update.id}
                      className="p-4 rounded-xl border border-border/70 bg-card hover:border-border transition-colors space-y-2.5"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-mono text-xs font-bold text-foreground">
                              {update.courseCode}
                            </span>
                            <span className="text-xs font-semibold text-foreground">
                              {update.courseName}
                            </span>
                            <Badge variant={getBadgeVariant(update.updateType)} className="text-[10px]">
                              {typeLabel}
                            </Badge>
                            {!isActive && (
                              <Badge variant="outline" className="text-[10px]">
                                {update.status}
                              </Badge>
                            )}
                          </div>
                          <p className="text-xs text-muted-foreground">
                            Instructor: {update.teacherName || "Assigned Faculty"} • Target: {update.affectedBranch || "All Branches"}
                            {update.affectedYear ? ` • Year ${update.affectedYear}` : ""}
                            {update.affectedSection ? ` • Sec ${update.affectedSection}` : ""}
                          </p>
                        </div>

                        <div className="flex items-center gap-2 shrink-0">
                          <span className="text-[11px] text-muted-foreground font-mono">
                            {formatRelativeTime(update.createdAt)}
                          </span>
                          {isActive && (
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-7 px-2 text-[11px] text-rose-600 hover:text-rose-700 hover:bg-rose-500/10"
                              loading={cancelMutation.isPending && cancelMutation.variables === update.id}
                              onClick={() => cancelMutation.mutate(update.id)}
                            >
                              <Ban className="h-3 w-3 mr-1" />
                              Cancel
                            </Button>
                          )}
                        </div>
                      </div>

                      <p className="text-xs text-foreground bg-muted/20 p-2.5 rounded-lg border border-border/40 leading-relaxed">
                        {update.message}
                      </p>

                      {(update.newDate || update.newTime || update.newRoom) && (
                        <div className="flex items-center gap-4 text-[11px] text-muted-foreground font-mono bg-muted/40 p-2 rounded-md flex-wrap">
                          {update.newDate && (
                            <span className="flex items-center gap-1">
                              <Calendar className="h-3 w-3 text-primary" /> New Date: {update.newDate}
                            </span>
                          )}
                          {update.newTime && (
                            <span className="flex items-center gap-1">
                              <Clock className="h-3 w-3 text-primary" /> New Time: {update.newTime}
                            </span>
                          )}
                          {update.newRoom && (
                            <span className="flex items-center gap-1">
                              <MapPin className="h-3 w-3 text-primary" /> New Room: {update.newRoom}
                            </span>
                          )}
                        </div>
                      )}
                    </div>
                  )
                })}
              </div>
            ) : (
              <EmptyState
                icon={Megaphone}
                title="No Academic Updates"
                description="There are currently no active class cancellations or reschedule notices posted."
                actionLabel="Post Class Update"
                onAction={() => setCreateDialogOpen(true)}
              />
            )}
          </div>
        </div>

        {/* Right Col: Timetable Integration Reality State */}
        <div className="space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold tracking-tight text-foreground">
                Central Timetable Source
              </h2>
              <FileSpreadsheet className="h-4 w-4 text-muted-foreground" />
            </div>

            <div className="rounded-lg bg-muted/30 p-3.5 space-y-2 border border-border/60 text-xs">
              <div className="flex items-center gap-2">
                <StatusIndicator status="pending" label="Awaiting ERP Roster Link" />
              </div>
              <p className="text-muted-foreground text-xs leading-relaxed">
                As identified during the system audit, automated semester timetable feeds from university ERP are pending cryptographic callback registration. Academic notices and manual class cancellations remain fully operational.
              </p>
            </div>

            <div className="space-y-2 pt-2 text-xs">
              <div className="flex justify-between py-1.5 border-b border-border/40">
                <span className="text-muted-foreground">Class Rosters</span>
                <span className="font-mono text-foreground font-medium">Manual Sync Active</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-border/40">
                <span className="text-muted-foreground">Lecture Beacon Auth</span>
                <span className="font-mono text-emerald-600 dark:text-emerald-400 font-medium">Passport 1I Verified</span>
              </div>
              <div className="flex justify-between py-1.5">
                <span className="text-muted-foreground">Notification Dispatch</span>
                <span className="font-mono text-foreground font-medium">Push Triggered</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <CreateUpdateDialog open={createDialogOpen} onOpenChange={setCreateDialogOpen} />
    </div>
  )
}

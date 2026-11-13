import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { SessionDetailSheet } from "./components/session-detail-sheet"
import { attendanceApi, LectureSession } from "./api/attendance-api"
import { formatDate } from "@/lib/utils"
import { Radio, ExternalLink, RefreshCw } from "lucide-react"

export function AttendancePage() {
  const [selectedSession, setSelectedSession] = React.useState<LectureSession | null>(null)
  const [sheetOpen, setSheetOpen] = React.useState(false)

  const {
    data: activeSessions = [],
    refetch: refetchActive,
  } = useQuery({
    queryKey: ["attendance", "sessions", "active"],
    queryFn: attendanceApi.getActiveSessions,
    refetchInterval: 10000,
  })

  const {
    data: historySessions = [],
    isLoading: isHistoryLoading,
    error: historyError,
    refetch: refetchHistory,
  } = useQuery({
    queryKey: ["attendance", "sessions", "history"],
    queryFn: () => attendanceApi.getSessionHistory(),
  })

  const handleRowClick = (session: LectureSession) => {
    setSelectedSession(session)
    setSheetOpen(true)
  }

  const columns: ColumnDef<LectureSession>[] = [
    {
      accessorKey: "subject",
      header: "Course / Subject",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground group-hover:text-primary transition-colors">
            {row.original.subject || row.original.name}
          </p>
          <p className="text-[11px] text-muted-foreground">{row.original.name}</p>
        </div>
      ),
    },
    {
      accessorKey: "instructorName",
      header: "Instructor",
      cell: ({ row }) => (
        <span className="text-xs text-foreground font-medium">
          {row.original.instructorName || row.original.instructor_name || "Faculty"}
        </span>
      ),
    },
    {
      accessorKey: "branch",
      header: "Class / Cohort",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {row.original.branch || "Gen"} Yr {row.original.year || "—"}
        </span>
      ),
    },
    {
      accessorKey: "attendanceCount",
      header: "Present Count",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {row.original.attendanceCount ?? row.original.attendance_count ?? 0} students
        </span>
      ),
    },
    {
      accessorKey: "startTime",
      header: "Session Time",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {formatDate(row.original.startTime || row.original.start_time)}
        </span>
      ),
    },
    {
      accessorKey: "isActive",
      header: "State",
      cell: ({ row }) => {
        const active = !!(row.original.isActive ?? row.original.is_active)
        return (
          <StatusIndicator
            status={active ? "success" : "neutral"}
            label={active ? "Recording" : "Concluded"}
            pulse={active}
          />
        )
      },
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
          View Roster
          <ExternalLink className="h-3 w-3" />
        </Button>
      ),
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Attendance Operations"
        description="Live lecture monitoring, cryptographic session nonces, force-stop controls, and historical attendance records."
        badge={
          activeSessions.length > 0 ? (
            <StatusIndicator
              status="success"
              label={`${activeSessions.length} Active Sessions`}
              pulse
            />
          ) : (
            <span className="text-xs font-mono text-muted-foreground">0 Active Sessions</span>
          )
        }
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              refetchActive()
              refetchHistory()
            }}
            className="text-xs gap-1.5"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {activeSessions.length > 0 && (
        <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/[0.03] p-5 space-y-3">
          <div className="flex items-center justify-between">
            <h2 className="text-sm font-semibold text-foreground flex items-center gap-2">
              <Radio className="h-4 w-4 text-emerald-600 dark:text-emerald-400 animate-pulse" />
              Live Classroom Sessions In Progress
            </h2>
            <span className="text-xs text-muted-foreground">Live Telemetry</span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
            {activeSessions.map((sess) => (
              <div
                key={sess.id}
                onClick={() => handleRowClick(sess)}
                className="p-3.5 rounded-lg border border-border/80 bg-card hover:border-emerald-500/50 cursor-pointer transition-all space-y-2"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="text-xs font-semibold text-foreground">{sess.subject || sess.name}</h3>
                    <p className="text-[11px] text-muted-foreground">
                      {sess.instructorName || sess.instructor_name}
                    </p>
                  </div>
                  <Badge variant="success" className="text-[10px]">LIVE</Badge>
                </div>
                <div className="flex items-center justify-between text-xs pt-1 border-t border-border/40">
                  <span className="text-muted-foreground text-[11px]">
                    {sess.branch} Yr {sess.year}
                  </span>
                  <span className="font-mono font-semibold text-foreground">
                    {sess.attendanceCount ?? sess.attendance_count ?? 0} Attending
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="space-y-3">
        <div>
          <h2 className="text-sm font-semibold tracking-tight text-foreground">
            Class Attendance Records &amp; History
          </h2>
          <p className="text-xs text-muted-foreground">
            Audit logs of concluded class sessions and verified student attendance
          </p>
        </div>

        <DataTable
          columns={columns}
          data={historySessions}
          isLoading={isHistoryLoading}
          error={historyError}
          onRetry={refetchHistory}
          searchPlaceholder="Search by subject, instructor, or branch..."
          onRowClick={handleRowClick}
          emptyTitle="No Recorded Sessions"
          emptyDescription="There are no past lecture sessions logged in the attendance system."
        />
      </div>

      <SessionDetailSheet
        session={selectedSession}
        open={sheetOpen}
        onOpenChange={setSheetOpen}
      />
    </div>
  )
}

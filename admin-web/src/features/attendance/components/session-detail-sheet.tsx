import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Sheet,
  SheetContent,
} from "@/components/ui/sheet"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ConfirmDialog } from "@/components/feedback/confirm-dialog"
import { useToast } from "@/components/ui/toast"
import { attendanceApi, LectureSession } from "../api/attendance-api"
import { formatDate } from "@/lib/utils"
import { Download, MapPin, StopCircle, User, Radio, Users } from "lucide-react"

interface SessionDetailSheetProps {
  session: LectureSession | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function SessionDetailSheet({ session, open, onOpenChange }: SessionDetailSheetProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [stopConfirmOpen, setStopConfirmOpen] = React.useState(false)

  const sessionId = session?.id || ""

  const { data: attendees = [], isLoading: isAttendeesLoading } = useQuery({
    queryKey: ["attendance", "session", sessionId],
    queryFn: () => attendanceApi.getSessionAttendance(sessionId),
    enabled: !!sessionId && open,
  })

  const stopMutation = useMutation({
    mutationFn: () => attendanceApi.stopSession(sessionId),
    onSuccess: () => {
      toast({
        title: "Lecture Session Concluded",
        description: `Attendance recording closed for ${session?.subject || session?.name}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["attendance"] })
      setStopConfirmOpen(false)
      onOpenChange(false)
    },
    onError: (err: unknown) => {
      toast({
        title: "Action Failed",
        description: err instanceof Error ? err.message : "Failed to conclude session",
        type: "error",
      })
    },
  })

  if (!session) return null

  const isActive = !!(session.isActive ?? session.is_active)
  const nonce = session.sessionNonce || session.session_nonce
  const instructor = session.instructorName || session.instructor_name
  const startTime = session.startTime || session.start_time
  const count = attendees.length || session.attendanceCount || session.attendance_count || 0

  const handleExportCsv = () => {
    if (!attendees.length) return
    const headers = ["Student Name", "User ID", "Status", "Verification Mode", "Check-in Time"]
    const rows = attendees.map((a) => [
      `"${a.studentName || ""}"`,
      `"${a.userId || ""}"`,
      `"${a.status || ""}"`,
      `"${a.verificationMode || "LEGACY"}"`,
      `"${a.checkInTime || ""}"`,
    ])
    const csv = [headers.join(","), ...rows.map((r) => r.join(","))].join("\n")
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" })
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = `attendance-${(session.subject || session.name || session.id).replace(/\s+/g, "-")}.csv`
    link.click()
    URL.revokeObjectURL(url)
  }

  return (
    <>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="right" className="w-full sm:max-w-xl flex flex-col p-0">
          <div className="p-6 border-b border-border/70 space-y-3">
            <div className="flex items-start justify-between gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <h2 className="text-base font-semibold text-foreground">
                    {session.subject || session.name}
                  </h2>
                  <Badge variant={isActive ? "success" : "secondary"} className="text-[10px]">
                    {isActive ? "LIVE RECORDING" : "CONCLUDED"}
                  </Badge>
                </div>
                <p className="text-xs text-muted-foreground">{session.name}</p>
              </div>

              <div className="text-right">
                <span className="text-xl font-bold font-mono text-foreground">{count}</span>
                <p className="text-[10px] text-muted-foreground">Present Attendees</p>
              </div>
            </div>

            <div className="flex items-center gap-3 text-xs text-muted-foreground flex-wrap">
              <span className="flex items-center gap-1">
                <User className="h-3.5 w-3.5 text-muted-foreground" /> {instructor || "Faculty"}
              </span>
              <span>•</span>
              <span className="flex items-center gap-1">
                <MapPin className="h-3.5 w-3.5 text-muted-foreground" /> {session.location || "Room Unspecified"}
              </span>
              <span>•</span>
              <span>{session.branch} Yr {session.year}</span>
            </div>
          </div>

          <div className="flex-1 overflow-y-auto p-6 space-y-5">
            <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2 text-xs">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-foreground flex items-center gap-1.5">
                  <Radio className="h-3.5 w-3.5 text-primary" />
                  Beacon Security Credentials
                </span>
                <StatusIndicator
                  status={nonce ? "success" : "neutral"}
                  label={nonce ? "Active Nonce" : "Legacy"}
                />
              </div>

              <div className="grid grid-cols-2 gap-2 pt-1 font-mono text-[11px]">
                <div className="bg-muted/30 p-2 rounded-lg">
                  <span className="text-muted-foreground text-[10px]">Started:</span>
                  <p className="text-foreground truncate">{formatDate(startTime)}</p>
                </div>
                <div className="bg-muted/30 p-2 rounded-lg">
                  <span className="text-muted-foreground text-[10px]">Session Nonce:</span>
                  <p className="text-foreground truncate">{nonce || "None"}</p>
                </div>
              </div>

              {isActive && (
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => setStopConfirmOpen(true)}
                  className="w-full text-xs gap-1.5 mt-2"
                >
                  <StopCircle className="h-3.5 w-3.5" />
                  Conclude &amp; Finalize Attendance Session
                </Button>
              )}
            </div>

            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Users className="h-3.5 w-3.5 text-muted-foreground" />
                  Verified Attendees List ({attendees.length})
                </h3>
                {attendees.length > 0 && (
                  <Button variant="outline" size="sm" onClick={handleExportCsv} className="h-7 text-xs gap-1">
                    <Download className="h-3 w-3" /> Export CSV
                  </Button>
                )}
              </div>

              {isAttendeesLoading ? (
                <div className="space-y-2">
                  {Array.from({ length: 4 }).map((_, i) => (
                    <Skeleton key={i} className="h-10 w-full" />
                  ))}
                </div>
              ) : attendees.length > 0 ? (
                <div className="divide-y divide-border/60 border border-border/80 rounded-xl bg-card overflow-hidden">
                  {attendees.map((attendee) => (
                    <div
                      key={attendee.id}
                      className="p-3 flex items-center justify-between gap-2 text-xs hover:bg-muted/30 transition-colors"
                    >
                      <div className="space-y-0.5">
                        <p className="font-semibold text-foreground">
                          {attendee.studentName || "Student"}
                        </p>
                        <p className="text-[10px] text-muted-foreground font-mono">
                          Check-in: {formatDate(attendee.checkInTime)}
                        </p>
                      </div>

                      <div className="text-right">
                        <Badge variant="success" className="text-[10px] px-1.5 py-0">
                          {attendee.status.toUpperCase()}
                        </Badge>
                        {attendee.verificationMode && (
                          <p className="text-[10px] text-muted-foreground font-mono mt-0.5">
                            {attendee.verificationMode}
                          </p>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-muted-foreground py-6 text-center">
                  No attendance records logged for this session yet.
                </p>
              )}
            </div>
          </div>
        </SheetContent>
      </Sheet>

      <ConfirmDialog
        open={stopConfirmOpen}
        onOpenChange={setStopConfirmOpen}
        title="Conclude Attendance Session"
        description={`Are you sure you want to stop recording attendance for '${session.subject || session.name}'? Students will no longer be able to check in.`}
        confirmLabel="Conclude Session"
        isLoading={stopMutation.isPending}
        onConfirm={async () => {
          await stopMutation.mutateAsync()
        }}
      />
    </>
  )
}

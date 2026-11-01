import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ConfirmDialog } from "@/components/feedback/confirm-dialog"
import { useToast } from "@/components/ui/toast"
import { attendanceApi, LectureSession, SessionAttendee } from "../api/attendance-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import { CalendarCheck, Clock, MapPin, StopCircle, User, Radio, Users } from "lucide-react"

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
        description: `Attendance recording closed for ${session?.subject}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["attendance"] })
      setStopConfirmOpen(false)
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Action Failed",
        description: err.message || "Failed to conclude session",
        type: "error",
      })
    },
  })

  if (!session) return null

  return (
    <>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="right" className="w-full sm:max-w-xl flex flex-col p-0">
          <div className="p-6 border-b border-border/70 space-y-3">
            <div className="flex items-start justify-between gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <h2 className="text-base font-semibold text-foreground">
                    {session.subject}
                  </h2>
                  <Badge variant={session.is_active ? "success" : "secondary"} className="text-[10px]">
                    {session.is_active ? "LIVE RECORDING" : "CONCLUDED"}
                  </Badge>
                </div>
                <p className="text-xs text-muted-foreground">{session.name}</p>
              </div>

              <div className="text-right">
                <span className="text-xl font-bold font-mono text-foreground">
                  {attendees.length || session.attendance_count || 0}
                </span>
                <p className="text-[10px] text-muted-foreground">Present Attendees</p>
              </div>
            </div>

            <div className="flex items-center gap-3 text-xs text-muted-foreground flex-wrap">
              <span className="flex items-center gap-1">
                <User className="h-3.5 w-3.5 text-muted-foreground" /> {session.instructor_name}
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
            {/* Session Cryptographic Telemetry */}
            <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2 text-xs">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-foreground flex items-center gap-1.5">
                  <Radio className="h-3.5 w-3.5 text-primary" />
                  Beacon Security Credentials
                </span>
                <StatusIndicator
                  status={session.session_nonce ? "success" : "neutral"}
                  label={session.session_nonce ? "Active Nonce" : "Legacy"}
                />
              </div>

              <div className="grid grid-cols-2 gap-2 pt-1 font-mono text-[11px]">
                <div className="bg-muted/30 p-2 rounded-lg">
                  <span className="text-muted-foreground text-[10px]">Started:</span>
                  <p className="text-foreground truncate">{formatDate(session.start_time)}</p>
                </div>
                <div className="bg-muted/30 p-2 rounded-lg">
                  <span className="text-muted-foreground text-[10px]">Session Nonce:</span>
                  <p className="text-foreground truncate">{session.session_nonce || "None"}</p>
                </div>
              </div>

              {session.is_active && (
                <Button
                  variant="destructive"
                  size="sm"
                  onClick={() => setStopConfirmOpen(true)}
                  className="w-full text-xs gap-1.5 mt-2"
                >
                  <StopCircle className="h-3.5 w-3.5" />
                  Conclude & Finalize Attendance Session
                </Button>
              )}
            </div>

            {/* Attendance Roster Table */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                  <Users className="h-3.5 w-3.5 text-muted-foreground" />
                  Verified Attendees List ({attendees.length})
                </h3>
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
        description={`Are you sure you want to stop recording attendance for '${session.subject}'? Students will no longer be able to check in.`}
        confirmLabel="Conclude Session"
        isLoading={stopMutation.isPending}
        onConfirm={async () => {
          await stopMutation.mutateAsync()
        }}
      />
    </>
  )
}

import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { Skeleton } from "@/components/ui/skeleton"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ConfirmDialog } from "@/components/feedback/confirm-dialog"
import { useToast } from "@/components/ui/toast"
import { studentsApi, StudentRecord } from "../api/students-api"
import { formatDate, formatRelativeTime, resolveMediaUrl } from "@/lib/utils"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import {
  CalendarCheck,
  Shield,
  Smartphone,
  KeyRound,
  FileText,
  AlertCircle,
  RotateCcw,
  CheckCircle2,
  Clock,
  XCircle,
  UserCheck,
  ZoomIn,
} from "lucide-react"

interface StudentDetailSheetProps {
  student: StudentRecord | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onStudentUpdated?: (updated: StudentRecord) => void
}

export function StudentDetailSheet({ student, open, onOpenChange, onStudentUpdated }: StudentDetailSheetProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [resetDialogOpen, setResetDialogOpen] = React.useState(false)
  const [rejectDialogOpen, setRejectDialogOpen] = React.useState(false)
  const [rejectReason, setRejectReason] = React.useState("")
  const [photoPreviewOpen, setPhotoPreviewOpen] = React.useState(false)

  const studentId = student?.id || ""

  // Queries for student operational telemetry
  const { data: analytics, isLoading: isAnalyticsLoading } = useQuery({
    queryKey: ["student", "analytics", studentId],
    queryFn: () => studentsApi.getStudentAnalytics(studentId),
    enabled: !!studentId && open,
  })

  const { data: attendanceHistory } = useQuery({
    queryKey: ["student", "attendance", studentId],
    queryFn: () => studentsApi.getStudentAttendance(studentId),
    enabled: !!studentId && open,
  })

  const { data: complaints } = useQuery({
    queryKey: ["student", "complaints", studentId],
    queryFn: () => studentsApi.getStudentComplaints(studentId),
    enabled: !!studentId && open,
  })

  const { data: passport } = useQuery({
    queryKey: ["student", "passport", studentId],
    queryFn: () => studentsApi.getStudentPassport(studentId),
    enabled: !!studentId && open,
  })

  const { data: gatePasses } = useQuery({
    queryKey: ["student", "gatePasses", studentId],
    queryFn: () => studentsApi.getStudentGatePasses(studentId),
    enabled: !!studentId && open,
  })

  // Device reset mutation
  const resetDeviceMutation = useMutation({
    mutationFn: () => studentsApi.resetDeviceId(studentId),
    onSuccess: () => {
      toast({
        title: "Device Binding Reset",
        description: `Hardware lock cleared for ${student?.name}. The student can now re-bind their official device.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      setResetDialogOpen(false)
    },
    onError: (err: any) => {
      toast({
        title: "Reset Failed",
        description: err.message || "Failed to reset device lock",
        type: "error",
      })
    },
  })

  // Approve registration mutation
  const approveMutation = useMutation({
    mutationFn: () => studentsApi.approveStudent(studentId),
    onSuccess: (res) => {
      toast({
        title: "Account Activated",
        description: `${student?.name}'s student account is now active and they can sign in.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard", "summary"] })
      onStudentUpdated?.(res.student)
    },
    onError: (err: any) => {
      toast({
        title: "Approval Failed",
        description: err.message || "Could not approve student account",
        type: "error",
      })
    },
  })

  // Reject registration mutation
  const rejectMutation = useMutation({
    mutationFn: (reason?: string) => studentsApi.rejectStudent(studentId, reason),
    onSuccess: (res) => {
      toast({
        title: "Registration Rejected",
        description: `${student?.name}'s registration has been rejected.`,
        type: "info",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard", "summary"] })
      setRejectDialogOpen(false)
      setRejectReason("")
      onStudentUpdated?.(res.student)
    },
    onError: (err: any) => {
      toast({
        title: "Rejection Failed",
        description: err.message || "Could not reject student registration",
        type: "error",
      })
    },
  })

  if (!student) return null

  const photoSrc = resolveMediaUrl(student.photoUrl)
  const approvalStatus = (student.approvalStatus || "APPROVED").toUpperCase()
  const approvalBadgeVariant =
    approvalStatus === "APPROVED"
      ? "success"
      : approvalStatus === "REJECTED"
      ? "destructive"
      : "warning"
  const approvalLabel =
    approvalStatus === "APPROVED"
      ? "Approved"
      : approvalStatus === "REJECTED"
      ? "Rejected"
      : "Pending Approval"

  return (
    <>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="right" className="w-full sm:max-w-xl flex flex-col p-0">
          {/* Header */}
          <div className="p-6 border-b border-border/70 space-y-3">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-start gap-3.5 min-w-0">
                {photoSrc ? (
                  <button
                    type="button"
                    onClick={() => setPhotoPreviewOpen(true)}
                    className="group relative h-14 w-14 shrink-0 rounded-xl overflow-hidden border border-border bg-muted shadow-sm focus:outline-none focus:ring-2 focus:ring-primary"
                    title="Click to inspect registration photo"
                  >
                    <img
                      src={photoSrc}
                      alt={student.name}
                      className="h-full w-full object-cover transition-transform group-hover:scale-105"
                    />
                    <span className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                      <ZoomIn className="h-4 w-4 text-white" />
                    </span>
                  </button>
                ) : (
                  <div className="h-14 w-14 shrink-0 rounded-xl border border-border bg-muted/60 flex items-center justify-center text-base font-bold text-muted-foreground">
                    {student.name?.charAt(0)?.toUpperCase() || "S"}
                  </div>
                )}

                <div className="space-y-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <h2 className="text-base font-semibold text-foreground truncate">
                      {student.name}
                    </h2>
                    <Badge variant="outline" className="font-mono text-[10px]">
                      {student.registrationNumber || "NO-REG"}
                    </Badge>
                    <Badge variant={approvalBadgeVariant} className="text-[10px]">
                      {approvalLabel}
                    </Badge>
                  </div>
                  <p className="text-xs text-muted-foreground truncate">{student.email}</p>
                </div>
              </div>

              <div className="text-right shrink-0">
                <span className="text-xl font-bold font-mono text-foreground">
                  {student.attendancePercentage ?? analytics?.overallPercentage ?? 0}%
                </span>
                <p className="text-[10px] text-muted-foreground">Attendance</p>
              </div>
            </div>

            {/* Academic metadata pill bar */}
            <div className="flex items-center gap-2 flex-wrap text-xs text-muted-foreground pt-1">
              <span className="rounded bg-muted/60 px-2 py-0.5 font-medium text-foreground">
                {student.branch || "General"}
              </span>
              <span>•</span>
              <span>Year {student.year || "1"}</span>
              <span>•</span>
              <span>{student.course || "B.Tech"}</span>
            </div>

            {/* WhatsApp & Guardian Contact Card */}
            <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
              <div className="flex items-center gap-1.5 rounded-lg border border-border/60 bg-muted/30 px-2.5 py-1.5">
                <Smartphone className="h-3.5 w-3.5 text-emerald-600 shrink-0" />
                <span className="text-muted-foreground">Student WhatsApp:</span>
                <span className="font-mono font-medium text-foreground truncate">
                  {student.phone || "Not linked"}
                </span>
              </div>
              <div className="flex items-center gap-1.5 rounded-lg border border-border/60 bg-muted/30 px-2.5 py-1.5">
                <Shield className="h-3.5 w-3.5 text-blue-600 shrink-0" />
                <span className="text-muted-foreground">Parent / Guardian:</span>
                <span className="font-mono font-medium text-foreground truncate">
                  {student.parentPhone ? `${student.parentPhone}${student.parentName ? ` (${student.parentName})` : ''}` : "Not provided"}
                </span>
              </div>
            </div>
          </div>

          {/* Operational Tabs */}
          <div className="flex-1 overflow-y-auto p-6">
            <Tabs defaultValue="overview" className="w-full">
              <TabsList className="grid grid-cols-4 w-full mb-4">
                <TabsTrigger value="overview">Overview</TabsTrigger>
                <TabsTrigger value="attendance">Attendance</TabsTrigger>
                <TabsTrigger value="identity">Passport</TabsTrigger>
                <TabsTrigger value="activity">Requests</TabsTrigger>
              </TabsList>

              {/* OVERVIEW TAB */}
              <TabsContent value="overview" className="space-y-5">
                {/* Account Activation Review Banner */}
                {approvalStatus !== "APPROVED" && (
                  <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 p-4 space-y-3">
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-1">
                        <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                          <UserCheck className="h-3.5 w-3.5 text-amber-600" />
                          {approvalStatus === "PENDING"
                            ? "Student Registration Pending Approval"
                            : "Registration Rejected"}
                        </h3>
                        <p className="text-xs text-muted-foreground">
                          {approvalStatus === "PENDING"
                            ? "Verify the student's uploaded photo and institutional details before activating their account."
                            : `Rejected${student.rejectionReason ? `: ${student.rejectionReason}` : "."}`}
                        </p>
                      </div>
                    </div>

                    {photoSrc && (
                      <div className="flex items-center gap-3 p-2.5 rounded-lg bg-card border border-border/70">
                        <img
                          src={photoSrc}
                          alt={`${student.name} registration photo`}
                          className="h-16 w-16 rounded-lg object-cover border border-border cursor-pointer"
                          onClick={() => setPhotoPreviewOpen(true)}
                        />
                        <div className="space-y-1 text-xs">
                          <p className="font-medium text-foreground">Submitted Verification Photo</p>
                          <p className="text-[11px] text-muted-foreground">
                            {student.createdAt ? `Submitted ${formatRelativeTime(student.createdAt)}` : "Uploaded during registration"}
                          </p>
                          <button
                            type="button"
                            onClick={() => setPhotoPreviewOpen(true)}
                            className="text-[11px] font-medium text-primary hover:underline"
                          >
                            Inspect full photo
                          </button>
                        </div>
                      </div>
                    )}

                    <div className="flex items-center gap-2 pt-1">
                      <Button
                        size="sm"
                        className="h-8 text-xs gap-1.5"
                        disabled={approveMutation.isPending || rejectMutation.isPending}
                        onClick={() => approveMutation.mutate()}
                      >
                        <CheckCircle2 className="h-3.5 w-3.5" />
                        {approveMutation.isPending ? "Activating..." : "Approve & Activate"}
                      </Button>
                      {approvalStatus === "PENDING" && (
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8 text-xs gap-1.5 text-destructive hover:text-destructive border-destructive/30 hover:bg-destructive/10"
                          disabled={approveMutation.isPending || rejectMutation.isPending}
                          onClick={() => setRejectDialogOpen(true)}
                        >
                          <XCircle className="h-3.5 w-3.5" />
                          Reject
                        </Button>
                      )}
                    </div>
                  </div>
                )}
                {/* Subject Attendance Breakdown */}
                <div className="rounded-xl border border-border/80 bg-card p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                      <CalendarCheck className="h-3.5 w-3.5 text-muted-foreground" />
                      Curricular Course Progress
                    </h3>
                    <span className="text-[11px] text-muted-foreground font-mono">
                      {analytics?.attendedClasses ?? 0} / {analytics?.totalClasses ?? 0} classes
                    </span>
                  </div>

                  {isAnalyticsLoading ? (
                    <div className="space-y-2">
                      <Skeleton className="h-8 w-full" />
                      <Skeleton className="h-8 w-full" />
                    </div>
                  ) : analytics?.subjects && analytics.subjects.length > 0 ? (
                    <div className="space-y-2.5">
                      {analytics.subjects.map((sub) => (
                        <div key={sub.subject} className="space-y-1">
                          <div className="flex items-center justify-between text-xs">
                            <span className="text-foreground font-medium">{sub.subject}</span>
                            <span className="font-mono text-xs">{sub.percentage}%</span>
                          </div>
                          <div className="h-1.5 w-full rounded-full bg-muted/60 overflow-hidden">
                            <div
                              className="h-full bg-primary rounded-full transition-all"
                              style={{ width: `${Math.min(100, sub.percentage)}%` }}
                            />
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground py-2">
                      No registered academic subjects found for this semester.
                    </p>
                  )}
                </div>

                {/* Device Identity State */}
                <div className="rounded-xl border border-border/80 bg-card p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                      <Smartphone className="h-3.5 w-3.5 text-muted-foreground" />
                      Hardware Device Lock
                    </h3>
                    <StatusIndicator
                      status={student.deviceId ? "success" : "pending"}
                      label={student.deviceId ? "Bound" : "Unbound"}
                    />
                  </div>

                  <div className="text-xs space-y-1 bg-muted/30 p-2.5 rounded-lg">
                    <p className="text-muted-foreground text-[11px]">Hardware Signature:</p>
                    <p className="font-mono text-[11px] break-all text-foreground">
                      {student.deviceId || "No hardware binding recorded (Account unlocked)"}
                    </p>
                  </div>

                  {student.deviceId && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => setResetDialogOpen(true)}
                      className="w-full text-xs gap-1.5 text-rose-600 dark:text-rose-400 border-rose-500/30 hover:bg-rose-500/10"
                    >
                      <RotateCcw className="h-3.5 w-3.5" />
                      Reset Device Lock Binding
                    </Button>
                  )}
                </div>

                {/* Recent Complaints Logged */}
                <div className="rounded-xl border border-border/80 bg-card p-4 space-y-3">
                  <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                    <AlertCircle className="h-3.5 w-3.5 text-muted-foreground" />
                    Complaints Filed ({complaints?.length || 0})
                  </h3>

                  {complaints && complaints.length > 0 ? (
                    <div className="space-y-2">
                      {complaints.slice(0, 3).map((c: any) => (
                        <div
                          key={c.id}
                          className="flex items-center justify-between p-2 rounded-lg bg-muted/20 text-xs"
                        >
                          <div className="min-w-0 pr-2">
                            <p className="font-medium text-foreground truncate">{c.title}</p>
                            <p className="text-[10px] text-muted-foreground">{c.category} • {formatRelativeTime(c.createdAt || c.created_at)}</p>
                          </div>
                          <Badge variant="secondary" className="text-[10px] shrink-0 font-mono">
                            {c.status}
                          </Badge>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground py-2">
                      No complaints lodged by this student.
                    </p>
                  )}
                </div>
              </TabsContent>

              {/* ATTENDANCE TAB */}
              <TabsContent value="attendance" className="space-y-3">
                <div className="flex items-center justify-between pb-2 border-b border-border/60">
                  <span className="text-xs font-semibold text-foreground">
                    Attendance Log ({attendanceHistory?.length || 0} checks)
                  </span>
                </div>

                {attendanceHistory && attendanceHistory.length > 0 ? (
                  <div className="space-y-2">
                    {attendanceHistory.map((item) => (
                      <div
                        key={item.id}
                        className="flex items-center justify-between p-2.5 rounded-lg border border-border/60 bg-card text-xs"
                      >
                        <div className="space-y-0.5">
                          <p className="font-medium text-foreground">
                            Session Check-in
                          </p>
                          <p className="text-[11px] text-muted-foreground font-mono">
                            {formatDate(item.checkInTime)}
                          </p>
                        </div>
                        <div className="text-right">
                          <Badge
                            variant={item.status === "present" ? "success" : "secondary"}
                            className="text-[10px]"
                          >
                            {item.status.toUpperCase()}
                          </Badge>
                          {item.verificationMode && (
                            <p className="text-[10px] text-muted-foreground font-mono mt-0.5">
                              {item.verificationMode}
                            </p>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-muted-foreground py-6 text-center">
                    No attendance records logged for this student.
                  </p>
                )}
              </TabsContent>

              {/* PASSPORT TAB */}
              <TabsContent value="identity" className="space-y-4">
                <div className="rounded-xl border border-border/80 bg-card p-4 space-y-3">
                  <div className="flex items-center justify-between">
                    <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                      <KeyRound className="h-3.5 w-3.5 text-muted-foreground" />
                      Passport Cryptographic Enrollment
                    </h3>
                    <StatusIndicator
                      status={passport?.status === "ACTIVE" ? "success" : "neutral"}
                      label={passport?.status || "NOT ENROLLED"}
                    />
                  </div>

                  {passport ? (
                    <div className="space-y-3 text-xs">
                      <div>
                        <span className="text-muted-foreground text-[11px]">Key ID:</span>
                        <p className="font-mono text-[11px] text-foreground">{passport.keyId}</p>
                      </div>

                      <div>
                        <span className="text-muted-foreground text-[11px]">Algorithm:</span>
                        <p className="font-mono text-[11px] text-foreground">
                          {passport.keyType} (Public Key Presentation)
                        </p>
                      </div>

                      <div>
                        <span className="text-muted-foreground text-[11px]">Public Key (Base64):</span>
                        <div className="rounded bg-muted/40 p-2 font-mono text-[10px] break-all select-all">
                          {passport.publicKey}
                        </div>
                      </div>

                      {passport.certificate && (
                        <div className="border-t border-border/60 pt-2 space-y-1">
                          <span className="text-muted-foreground text-[11px]">Certificate Validity:</span>
                          <p className="text-[11px] font-mono text-foreground">
                            {formatDate(passport.certificate.validFrom)} – {formatDate(passport.certificate.validTo)}
                          </p>
                          <Badge variant="success" className="text-[10px]">
                            {passport.certificate.status}
                          </Badge>
                        </div>
                      )}
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground py-4 text-center">
                      No active Passport identity key enrolled on this device.
                    </p>
                  )}
                </div>
              </TabsContent>

              {/* ACTIVITY / REQUESTS TAB */}
              <TabsContent value="activity" className="space-y-4">
                <div className="space-y-3">
                  <h3 className="text-xs font-semibold text-foreground">
                    Gate Passes & Movement History
                  </h3>

                  {gatePasses && gatePasses.length > 0 ? (
                    <div className="space-y-2">
                      {gatePasses.map((gp: any) => (
                        <div
                          key={gp.id}
                          className="p-3 rounded-lg border border-border/60 bg-card space-y-1 text-xs"
                        >
                          <div className="flex items-center justify-between">
                            <span className="font-medium text-foreground">
                              {gp.destination}
                            </span>
                            <Badge variant="outline" className="text-[10px] font-mono">
                              {gp.status}
                            </Badge>
                          </div>
                          <p className="text-[11px] text-muted-foreground">
                            Reason: {gp.reason}
                          </p>
                          <div className="flex items-center gap-3 text-[10px] text-muted-foreground font-mono pt-1">
                            <span>Exit: {formatDate(gp.expected_exit_time || gp.expectedExitTime)}</span>
                            <span>Return: {formatDate(gp.expected_return_time || gp.expectedReturnTime)}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground py-6 text-center">
                      No gate pass requests found for this student.
                    </p>
                  )}
                </div>
              </TabsContent>
            </Tabs>
          </div>
        </SheetContent>
      </Sheet>

      {/* Confirmation Dialog for Device Reset */}
      <ConfirmDialog
        open={resetDialogOpen}
        onOpenChange={setResetDialogOpen}
        title="Reset Hardware Device Binding"
        description={`This will clear the hardware device lock associated with ${student.name}'s account. The student will be required to re-authenticate and bind their approved device upon next login.`}
        confirmLabel="Reset Device Lock"
        isLoading={resetDeviceMutation.isPending}
        onConfirm={async () => {
          await resetDeviceMutation.mutateAsync()
        }}
      />

      {/* Reject Student Registration Dialog */}
      <Dialog open={rejectDialogOpen} onOpenChange={setRejectDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Reject Registration</DialogTitle>
            <DialogDescription>
              Provide an optional reason for rejecting {student.name}&apos;s registration request.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-2">
            <Input
              placeholder="e.g. Photo is unclear or registration number does not match"
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setRejectDialogOpen(false)}
              disabled={rejectMutation.isPending}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              size="sm"
              disabled={rejectMutation.isPending}
              onClick={() => rejectMutation.mutate(rejectReason.trim() || undefined)}
            >
              {rejectMutation.isPending ? "Rejecting..." : "Confirm Rejection"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Photo Preview Lightbox */}
      {photoSrc && (
        <Dialog open={photoPreviewOpen} onOpenChange={setPhotoPreviewOpen}>
          <DialogContent className="sm:max-w-md">
            <DialogHeader>
              <DialogTitle>{student.name}</DialogTitle>
              <DialogDescription>
                {student.registrationNumber || student.email} — Registration Photo
              </DialogDescription>
            </DialogHeader>
            <div className="overflow-hidden rounded-xl border border-border bg-muted/40">
              <img
                src={photoSrc}
                alt={student.name}
                className="w-full max-h-[65vh] object-contain"
              />
            </div>
          </DialogContent>
        </Dialog>
      )}
    </>
  )
}

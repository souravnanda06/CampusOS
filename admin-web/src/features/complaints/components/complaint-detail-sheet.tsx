import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import {
  Sheet,
  SheetContent,
} from "@/components/ui/sheet"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ComplaintLifecycleStepper } from "./complaint-lifecycle-stepper"
import { AssignDialog } from "./assign-dialog"
import { ActionDialog } from "./action-dialog"
import { complaintsApi } from "../api/complaints-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  AlertCircle,
  Clock,
  User,
  MapPin,
  UserCheck,
  CheckCircle2,
  XCircle,
  PlayCircle,
  RotateCcw,
  Check,
  Repeat,
  History,
  ShieldCheck,
  Flame,
  Star,
  KeyRound,
  AlertTriangle,
} from "lucide-react"

interface ComplaintDetailSheetProps {
  complaintId: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ComplaintDetailSheet({ complaintId, open, onOpenChange }: ComplaintDetailSheetProps) {
  const [assignOpen, setAssignOpen] = React.useState(false)
  const [actionType, setActionType] = React.useState<"START" | "RESOLVE" | "CLOSE" | "REOPEN" | "REJECT" | null>(null)
  const [actionOpen, setActionOpen] = React.useState(false)

  const { data, isLoading, error } = useQuery({
    queryKey: ["admin", "complaint", complaintId],
    queryFn: () => complaintsApi.getComplaintDetail(complaintId || ""),
    enabled: !!complaintId && open,
  })

  if (!complaintId) return null

  const c = data?.complaint
  const student = data?.student
  const staff = data?.assignedStaff
  const statusHistory = data?.statusHistory || []
  const auditHistory = data?.auditHistory || []

  const handleTriggerAction = (type: "START" | "RESOLVE" | "CLOSE" | "REOPEN" | "REJECT") => {
    setActionType(type)
    setActionOpen(true)
  }

  return (
    <>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="right" className="w-full sm:max-w-xl flex flex-col p-0">
          {isLoading ? (
            <div className="p-6 space-y-4">
              <Skeleton className="h-6 w-3/4" />
              <Skeleton className="h-20 w-full" />
              <Skeleton className="h-40 w-full" />
            </div>
          ) : c ? (
            <>
              {/* Header */}
              <div className="p-6 border-b border-border/70 space-y-3">
                <div className="flex items-start justify-between gap-3">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2 flex-wrap">
                      <h2 className="text-base font-semibold text-foreground">{c.title}</h2>
                      <Badge
                        variant={
                          c.priority === "URGENT"
                            ? "destructive"
                            : c.priority === "HIGH"
                            ? "warning"
                            : "secondary"
                        }
                        className="text-[10px]"
                      >
                        {c.priority}
                      </Badge>
                      {c.isAgeing && (
                        <Badge variant="destructive" className="text-[10px] gap-1">
                          <Clock className="h-3 w-3" /> Ageing ({c.ageHours}h)
                        </Badge>
                      )}
                    </div>
                    <p className="text-[11px] text-muted-foreground font-mono">
                      Ticket #{c.id} • {c.category}
                    </p>
                  </div>

                  <StatusIndicator
                    status={c.status}
                    label={c.status}
                    size="md"
                    className="font-mono text-xs uppercase"
                  />
                </div>

                {/* Stepper */}
                <div className="pt-2">
                  <ComplaintLifecycleStepper status={c.status} />
                </div>
              </div>

              {/* Body */}
              <div className="flex-1 overflow-y-auto p-6 space-y-5">
                {/* Contextual Action Bar */}
                <div className="flex items-center gap-2 flex-wrap bg-muted/30 p-2.5 rounded-xl border border-border/60">
                  <span className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mr-1">
                    Actions:
                  </span>

                  {(c.status === "PENDING" || c.status === "REOPENED") && (
                    <>
                      <Button size="sm" onClick={() => setAssignOpen(true)} className="h-7 text-xs">
                        Assign Staff
                      </Button>
                      {c.status === "PENDING" && (
                        <Button
                          variant="destructive"
                          size="sm"
                          onClick={() => handleTriggerAction("REJECT")}
                          className="h-7 text-xs"
                        >
                          Reject
                        </Button>
                      )}
                    </>
                  )}

                  {c.status === "ASSIGNED" && (
                    <>
                      <Button
                        size="sm"
                        onClick={() => handleTriggerAction("START")}
                        className="h-7 text-xs gap-1"
                      >
                        <PlayCircle className="h-3 w-3" /> Start Investigation
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => setAssignOpen(true)}
                        className="h-7 text-xs"
                      >
                        Re-assign
                      </Button>
                    </>
                  )}

                  {c.status === "IN_PROGRESS" && (
                    <Button
                      size="sm"
                      onClick={() => handleTriggerAction("RESOLVE")}
                      className="h-7 text-xs gap-1 bg-emerald-600 hover:bg-emerald-700"
                    >
                      <Check className="h-3 w-3" /> Mark Resolved
                    </Button>
                  )}

                  {c.status === "RESOLVED" && (
                    <>
                      <Button
                        size="sm"
                        onClick={() => handleTriggerAction("CLOSE")}
                        className="h-7 text-xs"
                      >
                        Close Ticket
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleTriggerAction("REOPEN")}
                        className="h-7 text-xs gap-1 text-amber-600 dark:text-amber-400"
                      >
                        <RotateCcw className="h-3 w-3" /> Reopen
                      </Button>
                    </>
                  )}

                  {c.status === "CLOSED" && (
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => handleTriggerAction("REOPEN")}
                      className="h-7 text-xs gap-1"
                    >
                      <RotateCcw className="h-3 w-3" /> Reopen Ticket
                    </Button>
                  )}
                </div>

                {/* SLA Escalation Warning Banner (if escalated) */}
                {c.escalationLevel === 3 && (
                  <div className="rounded-xl border border-rose-500/40 bg-rose-500/10 p-3.5 space-y-1.5 text-xs">
                    <div className="flex items-center gap-2 text-rose-600 dark:text-rose-400 font-semibold">
                      <Flame className="h-4 w-4 animate-pulse" />
                      <span>Tier 3 Dean Slingshot Active</span>
                      {c.vendorPenaltyFlag && (
                        <Badge variant="destructive" className="ml-auto text-[10px] font-mono">
                          -₹{c.vendorPenaltyAmount || 500} Vendor Penalty
                        </Badge>
                      )}
                    </div>
                    <p className="text-muted-foreground text-[11px] leading-relaxed">
                      This ticket exceeded the 48-hour institutional SLA and has been auto-escalated to the Dean of Student Welfare. A contract penalty deduction has been recorded.
                    </p>
                  </div>
                )}

                {c.escalationLevel === 2 && (
                  <div className="rounded-xl border border-amber-500/40 bg-amber-500/10 p-3.5 space-y-1.5 text-xs">
                    <div className="flex items-center gap-2 text-amber-600 dark:text-amber-400 font-semibold">
                      <AlertTriangle className="h-4 w-4" />
                      <span>Tier 2 Warden Alert</span>
                      <Badge variant="warning" className="ml-auto text-[10px] font-mono">
                        &gt;24h Breach
                      </Badge>
                    </div>
                    <p className="text-muted-foreground text-[11px] leading-relaxed">
                      This ticket exceeded the 24-hour turnaround target and has been auto-escalated to the Hostel Warden for expedited resolution.
                    </p>
                  </div>
                )}

                {/* Proof-of-Fix 2-Way OTP Status Card */}
                <div className="rounded-xl border border-emerald-500/30 bg-emerald-500/5 p-4 space-y-2.5 text-xs">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <ShieldCheck className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                      <h3 className="font-semibold text-foreground">Proof-of-Fix Protocol</h3>
                    </div>
                    {c.otpVerifiedAt || c.status === "RESOLVED" || c.status === "CLOSED" ? (
                      <span className="inline-flex items-center gap-1 text-[10px] font-mono font-semibold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-600 dark:text-emerald-400">
                        <CheckCircle2 className="h-3 w-3" /> Verified Handshake
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-[10px] font-mono font-semibold px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-600 dark:text-amber-400">
                        <KeyRound className="h-3 w-3" /> PIN Locked
                      </span>
                    )}
                  </div>

                  {c.otpVerifiedAt || c.status === "RESOLVED" || c.status === "CLOSED" ? (
                    <div className="space-y-1.5 text-[11px] text-muted-foreground">
                      <p>
                        Caretaker physically attended and verified resolution with the student owner.
                        {c.otpVerifiedAt && ` (Handshake completed: ${formatDate(c.otpVerifiedAt)})`}
                      </p>
                      {c.studentRating && (
                        <div className="pt-2 border-t border-emerald-500/20 flex items-center justify-between">
                          <span className="font-medium text-foreground">Student Satisfaction:</span>
                          <span className="font-bold text-amber-500 flex items-center gap-1">
                            {"★".repeat(c.studentRating)}{"☆".repeat(5 - c.studentRating)} ({c.studentRating}/5)
                          </span>
                        </div>
                      )}
                      {c.studentFeedback && (
                        <div className="bg-card/60 p-2 rounded border border-border/40 text-foreground italic">
                          "{c.studentFeedback}"
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="space-y-1.5 text-[11px] text-muted-foreground">
                      <p>
                        This ticket cannot be marked "Resolved" without physical student presence. The student holds a secret 4-digit PIN.
                      </p>
                      {c.closureOtp && (
                        <div className="flex items-center justify-between p-2 rounded bg-card/80 border border-border/50">
                          <span className="text-foreground font-medium">Student Closure PIN (Admin View):</span>
                          <span className="font-mono font-bold text-base tracking-widest text-emerald-600 dark:text-emerald-400">
                            {c.closureOtp}
                          </span>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* Complaint Description & Location */}
                <div className="space-y-3">
                  <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2 text-xs">
                    <h3 className="font-semibold text-foreground">Issue Description</h3>
                    <p className="text-muted-foreground leading-relaxed whitespace-pre-wrap">
                      {c.description}
                    </p>
                  </div>

                  <div className="grid grid-cols-2 gap-3 text-xs">
                    <div className="rounded-xl border border-border/80 bg-card p-3 space-y-1">
                      <span className="text-[11px] text-muted-foreground flex items-center gap-1">
                        <MapPin className="h-3 w-3" /> Location
                      </span>
                      <p className="font-medium text-foreground">{c.location || "General Campus"}</p>
                    </div>

                    <div className="rounded-xl border border-border/80 bg-card p-3 space-y-1">
                      <span className="text-[11px] text-muted-foreground flex items-center gap-1">
                        <UserCheck className="h-3 w-3" /> Assigned Staff
                      </span>
                      <p className="font-medium text-foreground">
                        {c.assignedToName || staff?.name || "Unassigned"}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Reporter Student Info */}
                {student && (
                  <div className="rounded-xl border border-border/80 bg-card p-4 space-y-2 text-xs">
                    <h3 className="font-semibold text-foreground flex items-center gap-1.5">
                      <User className="h-3.5 w-3.5 text-muted-foreground" />
                      Student Information
                    </h3>
                    <div className="grid grid-cols-2 gap-2 text-[11px]">
                      <div>
                        <span className="text-muted-foreground">Name:</span>
                        <p className="font-medium text-foreground">{student.name}</p>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Email:</span>
                        <p className="font-medium text-foreground truncate">{student.email}</p>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Registration:</span>
                        <p className="font-mono text-foreground">{student.registrationNumber || "—"}</p>
                      </div>
                      <div>
                        <span className="text-muted-foreground">Branch / Year:</span>
                        <p className="text-foreground">{student.branch || "General"} Yr {student.year || "1"}</p>
                      </div>
                    </div>
                  </div>
                )}

                {/* Status Transition History & Audit Timeline */}
                <div className="space-y-3">
                  <h3 className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                    <History className="h-3.5 w-3.5 text-muted-foreground" />
                    Operational Audit Timeline
                  </h3>

                  {statusHistory.length > 0 ? (
                    <div className="space-y-2">
                      {statusHistory.map((item, idx) => (
                        <div
                          key={item.id || idx}
                          className="flex items-start gap-3 p-2.5 rounded-lg border border-border/60 bg-card text-xs"
                        >
                          <div className="h-2 w-2 rounded-full bg-primary mt-1.5 shrink-0" />
                          <div className="flex-1 min-w-0 space-y-0.5">
                            <div className="flex items-center justify-between">
                              <span className="font-semibold text-foreground font-mono text-[11px]">
                                {item.oldStatus} → {item.newStatus}
                              </span>
                              <span className="text-[10px] text-muted-foreground font-mono">
                                {formatDate(item.timestamp)}
                              </span>
                            </div>
                            <p className="text-muted-foreground text-[11px] leading-relaxed">
                              {item.comment}
                            </p>
                            {item.actorName && (
                              <p className="text-[10px] text-muted-foreground">
                                By {item.actorName} ({item.actorRole})
                              </p>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-xs text-muted-foreground py-2">
                      No status transitions recorded yet.
                    </p>
                  )}
                </div>
              </div>
            </>
          ) : null}
        </SheetContent>
      </Sheet>

      {/* Action and Assign Modals */}
      <AssignDialog
        complaintId={complaintId}
        open={assignOpen}
        onOpenChange={setAssignOpen}
        currentAssigneeId={c?.assignedTo}
      />

      <ActionDialog
        complaintId={complaintId}
        action={actionType}
        open={actionOpen}
        onOpenChange={setActionOpen}
      />
    </>
  )
}

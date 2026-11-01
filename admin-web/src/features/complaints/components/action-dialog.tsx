import * as React from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { useToast } from "@/components/ui/toast"
import { complaintsApi } from "../api/complaints-api"

interface ActionDialogProps {
  complaintId: string
  action: "START" | "RESOLVE" | "CLOSE" | "REOPEN" | "REJECT" | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ActionDialog({ complaintId, action, open, onOpenChange }: ActionDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [remarks, setRemarks] = React.useState("")
  const [otp, setOtp] = React.useState("")

  React.useEffect(() => {
    if (open) {
      setRemarks("")
      setOtp("")
    }
  }, [open])

  const actionMutation = useMutation({
    mutationFn: () => {
      if (action === "RESOLVE") {
        return complaintsApi.verifyResolveComplaint(complaintId, otp.trim(), remarks.trim())
      }
      return complaintsApi.actionComplaint(complaintId, action || "", remarks)
    },
    onSuccess: (data) => {
      toast({
        title: action === "RESOLVE" ? "Complaint Verified & Resolved" : `Complaint ${action?.toLowerCase()}d`,
        description: `Operational status updated to ${data.complaint.status}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "complaints"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "complaint", complaintId] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Action Failed",
        description: err.message || "Failed to update complaint status",
        type: "error",
      })
    },
  })

  if (!action) return null

  const actionTitles: Record<string, { title: string; desc: string; button: string; variant?: "default" | "destructive" }> = {
    START: {
      title: "Begin Work on Complaint",
      desc: "Mark this complaint as actively being investigated or repaired.",
      button: "Start Work",
      variant: "default",
    },
    RESOLVE: {
      title: "Verify & Resolve Complaint",
      desc: "Require the student's 4-digit PIN to confirm work was physically inspected and completed.",
      button: "Verify & Resolve",
      variant: "default",
    },
    CLOSE: {
      title: "Close Complaint",
      desc: "Formally verify and close this resolved complaint.",
      button: "Close Complaint",
      variant: "default",
    },
    REOPEN: {
      title: "Reopen Complaint",
      desc: "Reactivate this ticket for further operational attention. Remarks explaining the remaining issue are required.",
      button: "Reopen Ticket",
      variant: "destructive",
    },
    REJECT: {
      title: "Reject Complaint",
      desc: "Dismiss this complaint if invalid or out of institutional scope. Reason remarks are required.",
      button: "Reject Complaint",
      variant: "destructive",
    },
  }

  const config = actionTitles[action] || {
    title: "Update Complaint",
    desc: "Perform operational transition on this ticket.",
    button: "Confirm",
  }

  const isRemarksRequired = ["RESOLVE", "REOPEN", "REJECT"].includes(action)
  const isOtpInvalid = action === "RESOLVE" && otp.trim().length !== 4

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>{config.title}</DialogTitle>
          <DialogDescription>{config.desc}</DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2">
          {action === "RESOLVE" && (
            <div className="space-y-1.5 p-3 rounded-lg bg-emerald-500/10 border border-emerald-500/30">
              <label className="text-xs font-semibold text-emerald-800 dark:text-emerald-300 flex items-center gap-1.5">
                <span>🔐 Student Closure PIN (Required)</span>
                <span className="text-destructive">*</span>
              </label>
              <Input
                type="text"
                maxLength={4}
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                placeholder="4-digit PIN provided by student"
                className="font-mono tracking-widest text-center text-lg font-bold bg-background"
              />
              <p className="text-[11px] text-muted-foreground">
                Staff/Caretakers must request this code from the student in person after completing the repair.
              </p>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">
              {action === "RESOLVE"
                ? "Resolution Summary / Fix Details"
                : action === "REOPEN"
                ? "Reason for Reopening"
                : action === "REJECT"
                ? "Rejection Justification"
                : "Operational Remarks (Optional)"}
              {isRemarksRequired && <span className="text-destructive ml-1">*</span>}
            </label>
            <textarea
              rows={3}
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              placeholder="Provide clear notes for the operational audit trail..."
              className="w-full rounded-lg border border-input bg-background p-2.5 text-xs shadow-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="sm"
            variant={config.variant || "default"}
            disabled={(isRemarksRequired && !remarks.trim()) || isOtpInvalid}
            loading={actionMutation.isPending}
            onClick={() => actionMutation.mutate()}
          >
            {config.button}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

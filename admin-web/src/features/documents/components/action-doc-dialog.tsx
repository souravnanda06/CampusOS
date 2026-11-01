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
import { documentsApi, DocumentRequestItem } from "../api/documents-api"

interface ActionDocDialogProps {
  document: DocumentRequestItem | null
  action: "APPROVE" | "REJECT" | "ISSUE" | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ActionDocDialog({ document, action, open, onOpenChange }: ActionDocDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [adminNotes, setAdminNotes] = React.useState("")

  React.useEffect(() => {
    if (open) setAdminNotes("")
  }, [open])

  const mutation = useMutation({
    mutationFn: () => documentsApi.actionRequest(document?.id || "", action || "APPROVE", adminNotes),
    onSuccess: (data) => {
      toast({
        title: `Document ${action === "ISSUE" ? "Issued" : action === "APPROVE" ? "Approved" : "Rejected"}`,
        description: `Request for ${data.document.studentName} updated to ${data.document.status}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["documents"] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Action Failed",
        description: err.message || "Failed to process document request",
        type: "error",
      })
    },
  })

  if (!document || !action) return null

  const isReject = action === "REJECT"
  const isIssue = action === "ISSUE"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {isIssue
              ? "Issue Official Institutional Document"
              : isReject
              ? "Reject Document Request"
              : "Approve Document Request"}
          </DialogTitle>
          <DialogDescription>
            {document.studentName} requested a {document.document_type} for: "{document.purpose}"
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2 text-xs">
          {isIssue && (
            <div className="rounded-lg bg-muted/40 p-3 space-y-1 border border-border/60">
              <span className="font-semibold text-foreground">Registry Issuance Notice:</span>
              <p className="text-muted-foreground leading-relaxed">
                Issuing this document generates a verifiable document registry number, signs metadata with the Registrar Authority, and activates the "Store in Wallet" presentation in the student application.
              </p>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">
              Registrar Notes {isReject ? "(Required)" : "(Optional)"}
            </label>
            <Input
              value={adminNotes}
              onChange={(e) => setAdminNotes(e.target.value)}
              placeholder={isReject ? "Reason for rejecting request..." : "e.g. Verified by Academic Section"}
              className="h-9 text-xs"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="sm"
            variant={isReject ? "destructive" : isIssue ? "default" : "default"}
            disabled={isReject && !adminNotes.trim()}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {isIssue ? "Sign & Issue Document" : isReject ? "Reject Request" : "Approve"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

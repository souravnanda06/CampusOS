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
import { hostelApi, HostelResidentRequest } from "../api/hostel-api"

interface ActionRequestDialogProps {
  request: HostelResidentRequest | null
  action: "APPROVE" | "REJECT" | "COMPLETE" | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ActionRequestDialog({ request, action, open, onOpenChange }: ActionRequestDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [remarks, setRemarks] = React.useState("")

  React.useEffect(() => {
    if (open) setRemarks("")
  }, [open])

  const mutation = useMutation({
    mutationFn: () => hostelApi.actionRequest(request?.id || "", action || "APPROVE", remarks),
    onSuccess: (data) => {
      toast({
        title: `Request ${action?.toLowerCase()}d`,
        description: `Hostel request has been ${data.request.status.toLowerCase()}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["hostel"] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Action Failed",
        description: err.message || "Failed to process hostel request",
        type: "error",
      })
    },
  })

  if (!request || !action) return null

  const isReject = action === "REJECT"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>
            {isReject ? "Reject Hostel Request" : action === "APPROVE" ? "Approve Hostel Request" : "Complete Request"}
          </DialogTitle>
          <DialogDescription>
            {request.studentName}'s request for {request.request_type} ({request.reason})
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">
              Warden Remarks {isReject ? "(Required)" : "(Optional)"}
            </label>
            <Input
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              placeholder="Add official notes for resident record..."
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
            variant={isReject ? "destructive" : "default"}
            disabled={isReject && !remarks.trim()}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {isReject ? "Reject Request" : "Confirm Approval"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

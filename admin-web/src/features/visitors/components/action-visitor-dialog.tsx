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
import { visitorsApi, VisitorRequestItem } from "../api/visitors-api"

interface ActionVisitorDialogProps {
  request: VisitorRequestItem | null
  action: "APPROVE" | "REJECT" | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ActionVisitorDialog({ request, action, open, onOpenChange }: ActionVisitorDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [remarks, setRemarks] = React.useState("")

  React.useEffect(() => {
    if (open) setRemarks("")
  }, [open])

  const mutation = useMutation({
    mutationFn: () => visitorsApi.actionRequest(request?.id || "", action || "APPROVE", remarks),
    onSuccess: (data) => {
      toast({
        title: `Visitor Pass ${action === "APPROVE" ? "Approved" : "Rejected"}`,
        description: `Pass for ${data.request.visitor_name} (${data.request.relation}) processed.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["visitors"] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Action Failed",
        description: err.message || "Failed to process visitor pass",
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
            {isReject ? "Reject Visitor Pass" : "Approve Visitor Gate Pass"}
          </DialogTitle>
          <DialogDescription>
            {request.visitor_name} visiting {request.studentName} for "{request.purpose}".
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2 text-xs">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">
              Approval Remarks {isReject ? "(Required)" : "(Optional)"}
            </label>
            <Input
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              placeholder={isReject ? "State reason for denying visitor access..." : "e.g. Identity verified"}
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
            {isReject ? "Reject Pass" : "Approve Pass"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useToast } from "@/components/ui/toast"
import { hostelApi, HostelAssetIssue } from "../api/hostel-api"

interface ActionAssetDialogProps {
  issue: HostelAssetIssue | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ActionAssetDialog({ issue, open, onOpenChange }: ActionAssetDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [status, setStatus] = React.useState<"ACKNOWLEDGED" | "IN_REPAIR" | "RESOLVED" | "CLOSED">("IN_REPAIR")
  const [resolutionNotes, setResolutionNotes] = React.useState("")

  React.useEffect(() => {
    if (issue) {
      setStatus(issue.status === "REPORTED" ? "ACKNOWLEDGED" : "IN_REPAIR")
      setResolutionNotes(issue.resolutionNotes || "")
    }
  }, [issue])

  const mutation = useMutation({
    mutationFn: () => hostelApi.actionAssetIssue(issue?.id || "", status, resolutionNotes),
    onSuccess: (data) => {
      toast({
        title: "Asset Issue Updated",
        description: `Status changed to ${data.issue.status}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["hostel"] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Update Failed",
        description: err.message || "Failed to update asset issue",
        type: "error",
      })
    },
  })

  if (!issue) return null

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Update Asset Maintenance Status</DialogTitle>
          <DialogDescription>
            Update the repair or resolution state for {issue.assetName} ({issue.assetCode}).
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Target Status</label>
            <Select value={status} onValueChange={(val: any) => setStatus(val)}>
              <SelectTrigger className="h-9 text-xs">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ACKNOWLEDGED">Acknowledged (Inspected)</SelectItem>
                <SelectItem value="IN_REPAIR">In Repair (Work Order Active)</SelectItem>
                <SelectItem value="RESOLVED">Resolved (Repaired / Replaced)</SelectItem>
                <SelectItem value="CLOSED">Closed (Verified)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Resolution / Work Notes</label>
            <textarea
              rows={3}
              value={resolutionNotes}
              onChange={(e) => setResolutionNotes(e.target.value)}
              placeholder="State repair action taken or replacement details..."
              className="w-full rounded-lg border border-input bg-background p-2.5 text-xs shadow-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button size="sm" loading={mutation.isPending} onClick={() => mutation.mutate()}>
            Save Status
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

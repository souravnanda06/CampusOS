import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
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
import { Input } from "@/components/ui/input"
import { useToast } from "@/components/ui/toast"
import { studentsApi } from "@/features/students/api/students-api"
import { complaintsApi } from "../api/complaints-api"

interface AssignDialogProps {
  complaintId: string
  open: boolean
  onOpenChange: (open: boolean) => void
  currentAssigneeId?: string | null
}

export function AssignDialog({ complaintId, open, onOpenChange, currentAssigneeId }: AssignDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [selectedStaff, setSelectedStaff] = React.useState<string>(currentAssigneeId || "")
  const [remarks, setRemarks] = React.useState<string>("")

  const { data: staffList = [] } = useQuery({
    queryKey: ["admin", "staff"],
    queryFn: studentsApi.getStaff,
    enabled: open,
  })

  const assignMutation = useMutation({
    mutationFn: () => complaintsApi.assignComplaint(complaintId, selectedStaff, remarks),
    onSuccess: (data) => {
      toast({
        title: "Complaint Assigned",
        description: `Successfully assigned to ${data.complaint.assignedToName || "staff member"}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "complaints"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "complaint", complaintId] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Assignment Failed",
        description: err.message || "Failed to assign complaint",
        type: "error",
      })
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Assign Complaint to Staff</DialogTitle>
          <DialogDescription>
            Delegate this operational issue to an authorized faculty or institutional staff member.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-2">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Select Staff Member</label>
            <Select value={selectedStaff} onValueChange={setSelectedStaff}>
              <SelectTrigger className="h-9 text-xs">
                <SelectValue placeholder="Choose institutional staff..." />
              </SelectTrigger>
              <SelectContent>
                {staffList.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.name} ({s.role}) {s.branch ? `• ${s.branch}` : ""}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Assignment Remarks (Optional)</label>
            <Input
              value={remarks}
              onChange={(e) => setRemarks(e.target.value)}
              placeholder="e.g. Please inspect water leak on 3rd floor by 4pm"
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
            disabled={!selectedStaff}
            loading={assignMutation.isPending}
            onClick={() => assignMutation.mutate()}
          >
            Confirm Assignment
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

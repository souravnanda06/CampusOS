import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useToast } from "@/components/ui/toast"
import { studentsApi } from "@/features/students/api/students-api"
import { hostelApi } from "../api/hostel-api"

interface AllocateRoomDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function AllocateRoomDialog({ open, onOpenChange }: AllocateRoomDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [studentId, setStudentId] = React.useState("")
  const [hostelName, setHostelName] = React.useState("Aryabhata Bhawan")
  const [block, setBlock] = React.useState("A")
  const [roomNumber, setRoomNumber] = React.useState("")
  const [bedNumber, setBedNumber] = React.useState("B1")
  const [occupancyType, setOccupancyType] = React.useState("DOUBLE")

  const { data: users = [] } = useQuery({
    queryKey: ["students", "all-for-hostel"],
    queryFn: () => studentsApi.getStudentsWithStats(),
    enabled: open,
  })

  React.useEffect(() => {
    if (open) {
      setStudentId("")
      setRoomNumber("")
      setBedNumber("B1")
    }
  }, [open])

  const mutation = useMutation({
    mutationFn: () =>
      hostelApi.upsertAllocation({
        studentId,
        hostelName: hostelName.trim(),
        block: block.trim(),
        roomNumber: roomNumber.trim(),
        bedNumber: bedNumber.trim(),
        occupancyType,
      }),
    onSuccess: (data) => {
      toast({
        title: "Room Allocation Saved",
        description: data.message || "Resident room assignment updated.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["hostel"] })
      onOpenChange(false)
    },
    onError: (err: Error) => {
      toast({
        title: "Allocation Failed",
        description: err.message || "Unable to allocate room",
        type: "error",
      })
    },
  })

  const canSubmit = Boolean(studentId && hostelName.trim() && roomNumber.trim())

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Allocate / Transfer Hostel Room</DialogTitle>
          <DialogDescription>
            Assign a student to a hostel bed or transfer their existing room allocation.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Student *</label>
            <Select value={studentId} onValueChange={setStudentId}>
              <SelectTrigger className="h-9 text-xs">
                <SelectValue placeholder="Select student..." />
              </SelectTrigger>
              <SelectContent>
                {users.map((u) => (
                  <SelectItem key={u.id} value={u.id}>
                    {u.name} ({u.registrationNumber || u.email})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Hostel Hall *</label>
              <Input
                value={hostelName}
                onChange={(e) => setHostelName(e.target.value)}
                placeholder="e.g. Aryabhata Bhawan"
                className="h-9 text-xs"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Block / Wing</label>
              <Input
                value={block}
                onChange={(e) => setBlock(e.target.value)}
                placeholder="e.g. A"
                className="h-9 text-xs"
              />
            </div>
          </div>

          <div className="grid grid-cols-3 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Room No *</label>
              <Input
                value={roomNumber}
                onChange={(e) => setRoomNumber(e.target.value)}
                placeholder="e.g. 204"
                className="h-9 text-xs font-mono"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Bed No</label>
              <Input
                value={bedNumber}
                onChange={(e) => setBedNumber(e.target.value)}
                placeholder="B1"
                className="h-9 text-xs font-mono"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Occupancy</label>
              <Select value={occupancyType} onValueChange={setOccupancyType}>
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="SINGLE">SINGLE</SelectItem>
                  <SelectItem value="DOUBLE">DOUBLE</SelectItem>
                  <SelectItem value="TRIPLE">TRIPLE</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="sm"
            disabled={!canSubmit}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            Save Allocation
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

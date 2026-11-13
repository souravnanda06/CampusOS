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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useToast } from "@/components/ui/toast"
import { feesApi, FeeRecordItem } from "../api/fees-api"

interface EditFeeDialogProps {
  fee: FeeRecordItem | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function EditFeeDialog({ fee, open, onOpenChange }: EditFeeDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [title, setTitle] = React.useState("")
  const [category, setCategory] = React.useState("TUITION")
  const [amount, setAmount] = React.useState(0)
  const [dueDate, setDueDate] = React.useState("")
  const [status, setStatus] = React.useState("DUE")

  React.useEffect(() => {
    if (fee && open) {
      setTitle(fee.title)
      setCategory(fee.category)
      setAmount(fee.amount)
      setDueDate(fee.dueDate)
      setStatus(fee.status)
    }
  }, [fee, open])

  const mutation = useMutation({
    mutationFn: () =>
      feesApi.updateFee(fee!.id, {
        title: title.trim(),
        category,
        amount: Number(amount),
        dueDate,
        status,
      }),
    onSuccess: () => {
      toast({
        title: "Fee Demand Updated",
        description: `Updated "${title}" successfully.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["fees"] })
      onOpenChange(false)
    },
    onError: (err: Error) => {
      toast({
        title: "Update Failed",
        description: err.message || "Could not update fee record.",
        type: "error",
      })
    },
  })

  if (!fee) return null

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Edit / Waive Fee Demand</DialogTitle>
          <DialogDescription>
            Modify fee terms or waive balance for {fee.studentName || "student"}.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Fee Title *</label>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="h-9 text-xs"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Category</label>
              <Select value={category} onValueChange={setCategory}>
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="TUITION">TUITION</SelectItem>
                  <SelectItem value="HOSTEL">HOSTEL</SelectItem>
                  <SelectItem value="EXAM">EXAM</SelectItem>
                  <SelectItem value="LIBRARY">LIBRARY</SelectItem>
                  <SelectItem value="OTHER">OTHER</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Status</label>
              <Select value={status} onValueChange={setStatus}>
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="DUE">DUE</SelectItem>
                  <SelectItem value="PARTIALLY_PAID">PARTIALLY_PAID</SelectItem>
                  <SelectItem value="OVERDUE">OVERDUE</SelectItem>
                  <SelectItem value="PAID">PAID</SelectItem>
                  <SelectItem value="WAIVED">WAIVED</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Amount (₹)</label>
              <Input
                type="number"
                min={1}
                value={amount}
                onChange={(e) => setAmount(Number(e.target.value))}
                className="h-9 text-xs font-mono"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Due Date</label>
              <Input
                type="date"
                value={dueDate}
                onChange={(e) => setDueDate(e.target.value)}
                className="h-9 text-xs font-mono"
              />
            </div>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="sm"
            disabled={!title.trim() || amount <= 0}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            Save Changes
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

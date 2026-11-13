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
import { feesApi, FeeRecordItem } from "../api/fees-api"
import { formatCurrency } from "@/lib/utils"

interface RecordPaymentDialogProps {
  fee: FeeRecordItem | null
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function RecordPaymentDialog({ fee, open, onOpenChange }: RecordPaymentDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [amount, setAmount] = React.useState<number>(0)

  React.useEffect(() => {
    if (fee) {
      const remaining = Math.max(0, fee.amount - fee.amountPaid)
      setAmount(remaining)
    }
  }, [fee])

  const mutation = useMutation({
    mutationFn: () => feesApi.recordPayment(fee?.id || "", amount),
    onSuccess: (data) => {
      toast({
        title: "Payment Recorded",
        description: `Receipt #${data.fee.receiptNumber || "ISSUED"} generated for ${data.fee.studentName || "student"}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["fees"] })
      onOpenChange(false)
    },
    onError: (err: Error) => {
      toast({
        title: "Payment Recording Failed",
        description: err.message || "Failed to record payment",
        type: "error",
      })
    },
  })

  if (!fee) return null

  const remaining = Math.max(0, fee.amount - fee.amountPaid)

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Record Fee Payment & Issue Receipt</DialogTitle>
          <DialogDescription>
            Record cashier receipt payment for {fee.studentName} ({fee.title}).
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2 text-xs">
          <div className="rounded-lg bg-muted/40 p-3 space-y-1.5 border border-border/60">
            <div className="flex justify-between">
              <span className="text-muted-foreground">Total Fee:</span>
              <span className="font-mono font-medium text-foreground">{formatCurrency(fee.amount)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted-foreground">Already Paid:</span>
              <span className="font-mono text-emerald-600 dark:text-emerald-400 font-medium">
                {formatCurrency(fee.amountPaid)}
              </span>
            </div>
            <div className="flex justify-between border-t border-border/40 pt-1.5">
              <span className="font-semibold text-foreground">Outstanding Balance:</span>
              <span className="font-mono font-bold text-foreground">{formatCurrency(remaining)}</span>
            </div>
          </div>

          <div className="space-y-1.5 pt-1">
            <label className="text-xs font-medium text-foreground">Payment Amount (₹)</label>
            <Input
              type="number"
              value={amount}
              onChange={(e) => setAmount(Number(e.target.value))}
              max={remaining}
              min={1}
              className="h-9 text-xs font-mono"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            size="sm"
            disabled={amount <= 0 || amount > remaining}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            Record & Generate Receipt
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

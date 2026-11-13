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
import { hostelApi } from "../api/hostel-api"

interface CreateAssetDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CreateAssetDialog({ open, onOpenChange }: CreateAssetDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [hostelName, setHostelName] = React.useState("Aryabhata Bhawan")
  const [roomNumber, setRoomNumber] = React.useState("")
  const [assetCode, setAssetCode] = React.useState("")
  const [assetName, setAssetName] = React.useState("")
  const [condition, setCondition] = React.useState("GOOD")

  React.useEffect(() => {
    if (open) {
      setRoomNumber("")
      setAssetCode("")
      setAssetName("")
      setCondition("GOOD")
    }
  }, [open])

  const mutation = useMutation({
    mutationFn: () =>
      hostelApi.createAsset({
        hostelName: hostelName.trim(),
        roomNumber: roomNumber.trim(),
        assetCode: assetCode.trim().toUpperCase(),
        assetName: assetName.trim(),
        condition,
      }),
    onSuccess: (data) => {
      toast({
        title: "Hostel Asset Added",
        description: data.message || "Asset registered in inventory.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["hostel"] })
      onOpenChange(false)
    },
    onError: (err: Error) => {
      toast({
        title: "Creation Failed",
        description: err.message || "Failed to add hostel asset",
        type: "error",
      })
    },
  })

  const canSubmit = Boolean(
    hostelName.trim() && roomNumber.trim() && assetCode.trim() && assetName.trim()
  )

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Register Hostel Asset</DialogTitle>
          <DialogDescription>
            Add tracked furniture or electrical equipment to a hostel room inventory.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3 py-2">
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
              <label className="text-xs font-medium text-foreground">Room No *</label>
              <Input
                value={roomNumber}
                onChange={(e) => setRoomNumber(e.target.value)}
                placeholder="e.g. 204"
                className="h-9 text-xs font-mono"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Asset Code *</label>
              <Input
                value={assetCode}
                onChange={(e) => setAssetCode(e.target.value)}
                placeholder="e.g. ARY-204-DESK1"
                className="h-9 text-xs font-mono uppercase"
              />
            </div>
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">Condition</label>
              <Select value={condition} onValueChange={setCondition}>
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="GOOD">GOOD</SelectItem>
                  <SelectItem value="FAIR">FAIR</SelectItem>
                  <SelectItem value="DAMAGED">DAMAGED</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Asset Name *</label>
            <Input
              value={assetName}
              onChange={(e) => setAssetName(e.target.value)}
              placeholder="e.g. Study Desk & Chair Set"
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
            disabled={!canSubmit}
            loading={mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            Add Asset
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

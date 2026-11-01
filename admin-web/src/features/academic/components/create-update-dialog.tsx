import * as React from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
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
import { academicApi, CreateClassUpdatePayload } from "../api/academic-api"

const schema = z.object({
  courseCode: z.string().min(2, "Course code is required (e.g. CS301)"),
  courseName: z.string().min(2, "Course name is required"),
  updateType: z.enum(["CANCELLED", "RESCHEDULED", "ROOM_CHANGE", "TIME_CHANGE", "ANNOUNCEMENT"]),
  originalDate: z.string().min(1, "Original date is required"),
  originalTime: z.string().optional(),
  originalRoom: z.string().optional(),
  newDate: z.string().optional(),
  newTime: z.string().optional(),
  newRoom: z.string().optional(),
  message: z.string().min(5, "Message detailing the operational change is required"),
  affectedBranch: z.string().min(1),
  affectedYear: z.coerce.number().optional(),
})

type FormValues = z.infer<typeof schema>

interface CreateUpdateDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CreateUpdateDialog({ open, onOpenChange }: CreateUpdateDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const {
    register,
    handleSubmit,
    setValue,
    watch,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      updateType: "ANNOUNCEMENT",
      affectedBranch: "ALL",
      originalDate: new Date().toISOString().split("T")[0],
    },
  })

  const updateType = watch("updateType")

  const mutation = useMutation({
    mutationFn: (values: FormValues) => academicApi.createUpdate(values as CreateClassUpdatePayload),
    onSuccess: (data) => {
      toast({
        title: "Class Update Published",
        description: `Delivered to ${data.affectedStudentsCount} affected student accounts.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["academic"] })
      reset()
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Publishing Failed",
        description: err.message || "Failed to post academic class update",
        type: "error",
      })
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Broadcast Academic Class Update</DialogTitle>
          <DialogDescription>
            Publish a formal schedule modification, class cancellation, or lecture announcement.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit((data) => mutation.mutate(data))} className="space-y-3.5">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Course Code</label>
              <Input {...register("courseCode")} placeholder="CS301" className="h-8 text-xs font-mono" />
              {errors.courseCode && <p className="text-[11px] text-destructive">{errors.courseCode.message}</p>}
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Course Name</label>
              <Input {...register("courseName")} placeholder="Data Structures" className="h-8 text-xs" />
              {errors.courseName && <p className="text-[11px] text-destructive">{errors.courseName.message}</p>}
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Update Type</label>
              <Select defaultValue="ANNOUNCEMENT" onValueChange={(val: any) => setValue("updateType", val)}>
                <SelectTrigger className="h-8 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ANNOUNCEMENT">General Announcement</SelectItem>
                  <SelectItem value="CANCELLED">Lecture Cancelled</SelectItem>
                  <SelectItem value="RESCHEDULED">Lecture Rescheduled</SelectItem>
                  <SelectItem value="ROOM_CHANGE">Room Change</SelectItem>
                  <SelectItem value="TIME_CHANGE">Time Change</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Target Branch</label>
              <Select defaultValue="ALL" onValueChange={(val) => setValue("affectedBranch", val)}>
                <SelectTrigger className="h-8 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">All Branches</SelectItem>
                  <SelectItem value="CSE">CSE</SelectItem>
                  <SelectItem value="ECE">ECE</SelectItem>
                  <SelectItem value="MECH">MECH</SelectItem>
                  <SelectItem value="CIVIL">CIVIL</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Scheduled Date</label>
              <Input type="date" {...register("originalDate")} className="h-8 text-xs" />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Scheduled Time</label>
              <Input {...register("originalTime")} placeholder="10:00 AM" className="h-8 text-xs" />
            </div>
          </div>

          {(updateType === "RESCHEDULED" || updateType === "ROOM_CHANGE" || updateType === "TIME_CHANGE") && (
            <div className="grid grid-cols-3 gap-2 bg-muted/30 p-2.5 rounded-lg border border-border/60">
              <div className="space-y-1">
                <label className="text-[11px] font-medium text-foreground">New Date</label>
                <Input type="date" {...register("newDate")} className="h-8 text-xs" />
              </div>
              <div className="space-y-1">
                <label className="text-[11px] font-medium text-foreground">New Time</label>
                <Input {...register("newTime")} placeholder="02:00 PM" className="h-8 text-xs" />
              </div>
              <div className="space-y-1">
                <label className="text-[11px] font-medium text-foreground">New Room</label>
                <Input {...register("newRoom")} placeholder="Hall 4" className="h-8 text-xs" />
              </div>
            </div>
          )}

          <div className="space-y-1">
            <label className="text-xs font-medium text-foreground">Notice Description / Instructions</label>
            <textarea
              {...register("message")}
              rows={3}
              placeholder="State the reason or instructions for affected students..."
              className="w-full rounded-lg border border-input bg-background p-2.5 text-xs shadow-sm focus:outline-none focus:ring-2 focus:ring-ring"
            />
            {errors.message && <p className="text-[11px] text-destructive">{errors.message.message}</p>}
          </div>

          <DialogFooter className="pt-2">
            <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" size="sm" loading={mutation.isPending}>
              Publish Update
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

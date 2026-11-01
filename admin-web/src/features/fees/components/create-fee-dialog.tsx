import * as React from "react"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
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
import { feesApi, CreateFeePayload } from "../api/fees-api"

const schema = z.object({
  studentId: z.string().min(1, "Select a student"),
  title: z.string().min(2, "Fee title is required (e.g. Semester 6 Tuition Fee)"),
  category: z.string().min(1),
  amount: z.coerce.number().positive("Amount must be greater than zero"),
  dueDate: z.string().min(1, "Due date is required"),
  academicYear: z.string().min(1),
  semester: z.coerce.number().min(1),
})

type FormValues = z.infer<typeof schema>

interface CreateFeeDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CreateFeeDialog({ open, onOpenChange }: CreateFeeDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const { data: students = [] } = useQuery({
    queryKey: ["admin", "students"],
    queryFn: () => studentsApi.getStudentsWithStats(),
    enabled: open,
  })

  const {
    register,
    handleSubmit,
    setValue,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      category: "TUITION",
      academicYear: "2025-2026",
      semester: 6,
      dueDate: new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString().split("T")[0],
    },
  })

  const mutation = useMutation({
    mutationFn: (values: FormValues) => feesApi.createFee(values as CreateFeePayload),
    onSuccess: () => {
      toast({
        title: "Fee Billed",
        description: "Official institutional fee record created successfully.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["fees"] })
      reset()
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Billing Failed",
        description: err.message || "Failed to create fee record",
        type: "error",
      })
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Bill Institutional Fee</DialogTitle>
          <DialogDescription>
            Issue a verified fee or dues demand note to an enrolled student account.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-3.5">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-foreground">Select Student</label>
            <Select onValueChange={(val) => setValue("studentId", val)}>
              <SelectTrigger className="h-9 text-xs">
                <SelectValue placeholder="Choose student account..." />
              </SelectTrigger>
              <SelectContent className="max-h-60">
                {students.map((s) => (
                  <SelectItem key={s.id} value={s.id}>
                    {s.name} ({s.registrationNumber || s.email}) • {s.branch}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {errors.studentId && <p className="text-[11px] text-destructive">{errors.studentId.message}</p>}
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-foreground">Fee Description / Title</label>
            <Input {...register("title")} placeholder="e.g. Semester 6 Tuition Fee" className="h-8 text-xs" />
            {errors.title && <p className="text-[11px] text-destructive">{errors.title.message}</p>}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Category</label>
              <Select defaultValue="TUITION" onValueChange={(val) => setValue("category", val)}>
                <SelectTrigger className="h-8 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="TUITION">Tuition</SelectItem>
                  <SelectItem value="HOSTEL">Hostel Rent & Mess</SelectItem>
                  <SelectItem value="EXAM">Examination</SelectItem>
                  <SelectItem value="LIBRARY">Library Fine</SelectItem>
                  <SelectItem value="OTHER">Other Institutional Dues</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1">
              <label className="text-xs font-medium text-foreground">Amount (₹)</label>
              <Input type="number" {...register("amount")} placeholder="45000" className="h-8 text-xs font-mono" />
              {errors.amount && <p className="text-[11px] text-destructive">{errors.amount.message}</p>}
            </div>
          </div>

          <div className="space-y-1">
            <label className="text-xs font-medium text-foreground">Due Date</label>
            <Input type="date" {...register("dueDate")} className="h-8 text-xs" />
            {errors.dueDate && <p className="text-[11px] text-destructive">{errors.dueDate.message}</p>}
          </div>

          <DialogFooter className="pt-2">
            <Button type="button" variant="outline" size="sm" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" size="sm" loading={mutation.isPending}>
              Issue Fee Record
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

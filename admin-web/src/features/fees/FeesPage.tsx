import * as React from "react"
import { useSearchParams } from "react-router-dom"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { ConfirmDialog } from "@/components/feedback/confirm-dialog"
import { useToast } from "@/components/ui/toast"
import { CreateFeeDialog } from "./components/create-fee-dialog"
import { EditFeeDialog } from "./components/edit-fee-dialog"
import { RecordPaymentDialog } from "./components/record-payment-dialog"
import { feesApi, FeeRecordItem } from "./api/fees-api"
import { formatCurrency } from "@/lib/utils"
import {
  Plus,
  CreditCard,
  FileCheck,
  Pencil,
  Trash2,
} from "lucide-react"

export function FeesPage() {
  const [searchParams, setSearchParams] = useSearchParams()
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [createFeeOpen, setCreateFeeOpen] = React.useState(false)
  const [selectedFee, setSelectedFee] = React.useState<FeeRecordItem | null>(null)
  const [paymentDialogOpen, setPaymentDialogOpen] = React.useState(false)
  const [editDialogOpen, setEditDialogOpen] = React.useState(false)
  const [feeToDelete, setFeeToDelete] = React.useState<FeeRecordItem | null>(null)

  const initialStatus = searchParams.get("status")?.toUpperCase() || "ALL"
  const [statusFilter, setStatusFilter] = React.useState<string>(initialStatus)
  const [categoryFilter, setCategoryFilter] = React.useState<string>("ALL")

  const handleStatusChange = (val: string) => {
    setStatusFilter(val)
    const next = new URLSearchParams(searchParams)
    if (val === "ALL") {
      next.delete("status")
    } else {
      next.set("status", val)
    }
    setSearchParams(next, { replace: true })
  }

  const { data: kpis } = useQuery({
    queryKey: ["fees", "kpis"],
    queryFn: feesApi.getKpis,
  })

  const {
    data: fees = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["fees", "all", statusFilter, categoryFilter],
    queryFn: () =>
      feesApi.getAllFees({
        status: statusFilter !== "ALL" ? statusFilter : undefined,
        category: categoryFilter !== "ALL" ? categoryFilter : undefined,
      }),
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => feesApi.deleteFee(id),
    onSuccess: (res) => {
      toast({
        title: "Fee Demand Cancelled",
        description: res.message || "Unpaid fee demand removed.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["fees"] })
      setFeeToDelete(null)
    },
    onError: (err: Error) => {
      toast({
        title: "Cannot Cancel Demand",
        description: err.message || "Failed to delete fee record.",
        type: "error",
      })
    },
  })

  const columns: ColumnDef<FeeRecordItem>[] = [
    {
      accessorKey: "studentName",
      header: "Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName || "Student"}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch || "—"})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "title",
      header: "Fee Description",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.title}</p>
          <p className="text-[10px] text-muted-foreground">
            {row.original.category} • Sem {row.original.semester}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "amount",
      header: "Total Billed",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {formatCurrency(row.original.amount)}
        </span>
      ),
    },
    {
      accessorKey: "amountPaid",
      header: "Paid",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-emerald-600 dark:text-emerald-400 font-medium">
          {formatCurrency(row.original.amountPaid)}
        </span>
      ),
    },
    {
      accessorKey: "dueDate",
      header: "Due Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {row.original.dueDate}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => {
        const status = row.original.status
        const variant =
          status === "PAID" || status === "WAIVED"
            ? "success"
            : status === "OVERDUE"
              ? "destructive"
              : status === "PARTIALLY_PAID"
                ? "warning"
                : "secondary"
        return (
          <Badge variant={variant} className="text-[10px] font-mono">
            {status}
          </Badge>
        )
      },
    },
    {
      accessorKey: "receiptNumber",
      header: "Receipt #",
      cell: ({ row }) => (
        <span className="text-[11px] text-muted-foreground font-mono">
          {row.original.receiptNumber || "—"}
        </span>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const fee = row.original
        const isSettled = fee.status === "PAID" || fee.status === "WAIVED"
        return (
          <div className="flex items-center gap-1.5">
            {!isSettled ? (
              <Button
                variant="outline"
                size="sm"
                onClick={() => {
                  setSelectedFee(fee)
                  setPaymentDialogOpen(true)
                }}
                className="text-xs h-7 gap-1"
              >
                <CreditCard className="h-3 w-3" /> Record Payment
              </Button>
            ) : (
              <span className="text-[11px] text-emerald-600 dark:text-emerald-400 flex items-center gap-1 font-medium px-1">
                <FileCheck className="h-3 w-3" /> {fee.status === "WAIVED" ? "Waived" : "Settled"}
              </span>
            )}
            <Button
              variant="ghost"
              size="sm"
              className="h-7 w-7 p-0"
              title="Edit or Waive Fee"
              onClick={() => {
                setSelectedFee(fee)
                setEditDialogOpen(true)
              }}
            >
              <Pencil className="h-3.5 w-3.5" />
            </Button>
            {fee.amountPaid === 0 && (
              <Button
                variant="ghost"
                size="sm"
                className="h-7 w-7 p-0 text-rose-600 hover:text-rose-700 hover:bg-rose-500/10"
                title="Cancel Fee Demand"
                onClick={() => setFeeToDelete(fee)}
              >
                <Trash2 className="h-3.5 w-3.5" />
              </Button>
            )}
          </div>
        )
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Fees & Dues Accounting"
        description="Institutional dues reconciliation, receipts management, fee structures, and collection auditability."
        badge={
          <span className="text-xs font-mono text-muted-foreground">
            {fees.length} Total Demands
          </span>
        }
        actions={
          <Button size="sm" onClick={() => setCreateFeeOpen(true)} className="gap-1.5 text-xs">
            <Plus className="h-3.5 w-3.5" />
            Bill New Fee Record
          </Button>
        }
      />

      {/* Financial KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Total Billed</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis ? formatCurrency(kpis.totalBilled) : "—"}
          </p>
          <p className="text-[11px] text-muted-foreground">Total institutional dues</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Total Collected</p>
          <p className="text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            {kpis ? formatCurrency(kpis.totalCollected) : "—"}
          </p>
          <p className="text-[11px] text-muted-foreground">Cashier & bank receipts</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Total Outstanding</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis ? formatCurrency(kpis.totalOutstanding) : "—"}
          </p>
          <p className="text-[11px] text-muted-foreground">Uncollected balance</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Overdue Dues</p>
          <p className="text-2xl font-bold font-mono text-rose-600 dark:text-rose-400">
            {kpis ? formatCurrency(kpis.overdueAmount) : "—"}
          </p>
          <p className="text-[11px] text-muted-foreground">{kpis?.overdueCount ?? 0} overdue accounts</p>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={fees}
        isLoading={isLoading}
        error={error}
        onRetry={refetch}
        searchPlaceholder="Search by student name, reg number, receipt, or fee title..."
        emptyTitle="No Fee Records Found"
        emptyDescription="There are no fee records matching the selected status or category parameters."
        toolbarSlot={
          <div className="flex items-center gap-2">
            <Select value={statusFilter} onValueChange={handleStatusChange}>
              <SelectTrigger className="w-36 h-8 text-xs bg-card">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">All Statuses</SelectItem>
                <SelectItem value="DUE">Due</SelectItem>
                <SelectItem value="PARTIALLY_PAID">Partially Paid</SelectItem>
                <SelectItem value="PAID">Paid</SelectItem>
                <SelectItem value="OVERDUE">Overdue</SelectItem>
                <SelectItem value="WAIVED">Waived</SelectItem>
              </SelectContent>
            </Select>

            <Select value={categoryFilter} onValueChange={setCategoryFilter}>
              <SelectTrigger className="w-32 h-8 text-xs bg-card">
                <SelectValue placeholder="Category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">All Categories</SelectItem>
                <SelectItem value="TUITION">Tuition</SelectItem>
                <SelectItem value="HOSTEL">Hostel</SelectItem>
                <SelectItem value="EXAM">Exam</SelectItem>
                <SelectItem value="LIBRARY">Library</SelectItem>
                <SelectItem value="OTHER">Other</SelectItem>
              </SelectContent>
            </Select>
          </div>
        }
      />

      <CreateFeeDialog open={createFeeOpen} onOpenChange={setCreateFeeOpen} />
      <EditFeeDialog fee={selectedFee} open={editDialogOpen} onOpenChange={setEditDialogOpen} />
      <RecordPaymentDialog
        fee={selectedFee}
        open={paymentDialogOpen}
        onOpenChange={setPaymentDialogOpen}
      />
      <ConfirmDialog
        open={!!feeToDelete}
        onOpenChange={(open) => !open && setFeeToDelete(null)}
        title="Cancel Fee Demand"
        description={`Remove unpaid fee demand "${feeToDelete?.title}" (${formatCurrency(feeToDelete?.amount || 0)}) for ${feeToDelete?.studentName || "student"}?`}
        confirmLabel="Cancel Demand"
        variant="destructive"
        isLoading={deleteMutation.isPending}
        onConfirm={() => {
          if (feeToDelete) deleteMutation.mutate(feeToDelete.id)
        }}
      />
    </div>
  )
}

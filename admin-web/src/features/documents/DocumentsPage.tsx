import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ActionDocDialog } from "./components/action-doc-dialog"
import { documentsApi, DocumentRequestItem } from "./api/documents-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  FileText,
  Wallet,
  CheckCircle2,
  Clock,
  Send,
  RefreshCw,
  FileCheck,
} from "lucide-react"

export function DocumentsPage() {
  const [statusFilter, setStatusFilter] = React.useState<string>("ALL")
  const [selectedDoc, setSelectedDoc] = React.useState<DocumentRequestItem | null>(null)
  const [actionType, setActionType] = React.useState<"APPROVE" | "REJECT" | "ISSUE" | null>(null)
  const [actionOpen, setActionOpen] = React.useState(false)

  const { data: kpis } = useQuery({
    queryKey: ["documents", "kpis"],
    queryFn: documentsApi.getKpis,
  })

  const {
    data: documents = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ["documents", "all", statusFilter],
    queryFn: () => documentsApi.getAllRequests(statusFilter),
  })

  const columns: ColumnDef<DocumentRequestItem>[] = [
    {
      accessorKey: "studentName",
      header: "Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch} Yr {row.original.year})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "document_type",
      header: "Document Requested",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <Badge variant="outline" className="font-mono text-xs">
            {row.original.document_type}
          </Badge>
          <p className="text-[10px] text-muted-foreground max-w-xs truncate">{row.original.purpose}</p>
        </div>
      ),
    },
    {
      accessorKey: "document_number",
      header: "Document Registry #",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-foreground">
          {row.original.document_number || "Awaiting Registry #"}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => {
        const status = row.original.status
        const variant =
          status === "ISSUED"
            ? "success"
            : status === "APPROVED"
            ? "info"
            : status === "REJECTED"
            ? "destructive"
            : "secondary"
        return (
          <Badge variant={variant} className="text-[10px] font-mono">
            {status}
          </Badge>
        )
      },
    },
    {
      accessorKey: "stored_in_wallet",
      header: "Student Wallet",
      cell: ({ row }) => {
        const inWallet = row.original.stored_in_wallet
        if (inWallet) {
          return (
            <span className="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-600 dark:text-emerald-400">
              <Wallet className="h-3.5 w-3.5" /> Enrolled
            </span>
          )
        }
        return <span className="text-[11px] text-muted-foreground font-mono">—</span>
      },
    },
    {
      accessorKey: "created_at",
      header: "Requested",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {formatRelativeTime(row.original.created_at)}
        </span>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        const d = row.original
        if (d.status === "PENDING") {
          return (
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedDoc(d)
                  setActionType("APPROVE")
                  setActionOpen(true)
                }}
              >
                Approve
              </Button>
              <Button
                variant="destructive"
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedDoc(d)
                  setActionType("REJECT")
                  setActionOpen(true)
                }}
              >
                Reject
              </Button>
            </div>
          )
        }
        if (d.status === "APPROVED") {
          return (
            <Button
              size="sm"
              className="h-7 text-xs gap-1 bg-emerald-600 hover:bg-emerald-700"
              onClick={() => {
                setSelectedDoc(d)
                setActionType("ISSUE")
                setActionOpen(true)
              }}
            >
              <Send className="h-3 w-3" /> Issue Document
            </Button>
          )
        }
        return (
          <span className="text-xs text-muted-foreground font-mono">
            {d.status === "ISSUED" ? "Active" : "Archived"}
          </span>
        )
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Official Documents Control"
        description="Verification, administrative approval, registrar issuance, and Campus Wallet provisioning."
        badge={
          <span className="text-xs font-mono text-muted-foreground">
            {documents.length} Total Requests
          </span>
        }
        actions={
          <Button variant="outline" size="sm" onClick={() => refetch()} className="text-xs gap-1.5">
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {/* Document KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Pending Verification</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis?.pendingRequests ?? documents.filter((d) => d.status === "PENDING").length}
          </p>
          <p className="text-[11px] text-muted-foreground">Awaiting registrar review</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Approved (Awaiting Issuance)</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {kpis?.approvedAwaitingIssue ?? documents.filter((d) => d.status === "APPROVED").length}
          </p>
          <p className="text-[11px] text-muted-foreground">Ready for official signature</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Officially Issued</p>
          <p className="text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
            {kpis?.totalIssued ?? documents.filter((d) => d.status === "ISSUED").length}
          </p>
          <p className="text-[11px] text-muted-foreground">In circulation & Wallet</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Rejected</p>
          <p className="text-2xl font-bold font-mono text-rose-600 dark:text-rose-400">
            {kpis?.totalRejected ?? documents.filter((d) => d.status === "REJECTED").length}
          </p>
          <p className="text-[11px] text-muted-foreground">Ineligible requests</p>
        </div>
      </div>

      <DataTable
        columns={columns}
        data={documents}
        isLoading={isLoading}
        error={error}
        onRetry={refetch}
        searchPlaceholder="Search by student name or document type..."
        searchColumnId="studentName"
        emptyTitle="No Document Requests Found"
        emptyDescription="There are no document requests matching the selected status parameter."
        toolbarSlot={
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-36 h-8 text-xs bg-card">
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Statuses</SelectItem>
              <SelectItem value="PENDING">Pending</SelectItem>
              <SelectItem value="APPROVED">Approved</SelectItem>
              <SelectItem value="ISSUED">Issued</SelectItem>
              <SelectItem value="REJECTED">Rejected</SelectItem>
            </SelectContent>
          </Select>
        }
      />

      <ActionDocDialog
        document={selectedDoc}
        action={actionType}
        open={actionOpen}
        onOpenChange={setActionOpen}
      />
    </div>
  )
}

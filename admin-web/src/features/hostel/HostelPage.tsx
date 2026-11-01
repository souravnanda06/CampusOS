import * as React from "react"
import { useQuery } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ActionAssetDialog } from "./components/action-asset-dialog"
import { ActionRequestDialog } from "./components/action-request-dialog"
import { hostelApi, HostelAllocationRecord, HostelAssetIssue, HostelResidentRequest } from "./api/hostel-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  Building2,
  Bed,
  Wrench,
  Inbox,
  AlertTriangle,
  CheckCircle2,
  RefreshCw,
} from "lucide-react"

export function HostelPage() {
  const [selectedIssue, setSelectedIssue] = React.useState<HostelAssetIssue | null>(null)
  const [assetActionOpen, setAssetActionOpen] = React.useState(false)

  const [selectedRequest, setSelectedRequest] = React.useState<HostelResidentRequest | null>(null)
  const [requestAction, setRequestAction] = React.useState<"APPROVE" | "REJECT" | "COMPLETE" | null>(null)
  const [requestActionOpen, setRequestActionOpen] = React.useState(false)

  const { data: kpis } = useQuery({
    queryKey: ["hostel", "kpis"],
    queryFn: hostelApi.getKpis,
  })

  const {
    data: allocations = [],
    isLoading: isAllocLoading,
    error: allocError,
    refetch: refetchAlloc,
  } = useQuery({
    queryKey: ["hostel", "allocations"],
    queryFn: hostelApi.getAllocations,
  })

  const {
    data: assetIssues = [],
    isLoading: isIssuesLoading,
    error: issuesError,
    refetch: refetchIssues,
  } = useQuery({
    queryKey: ["hostel", "assetIssues"],
    queryFn: hostelApi.getAssetIssues,
  })

  const {
    data: residentRequests = [],
    isLoading: isReqsLoading,
    error: reqsError,
    refetch: refetchReqs,
  } = useQuery({
    queryKey: ["hostel", "requests"],
    queryFn: hostelApi.getRequests,
  })

  // Allocation columns
  const allocationColumns: ColumnDef<HostelAllocationRecord>[] = [
    {
      accessorKey: "hostel_name",
      header: "Hostel Hall",
      cell: ({ row }) => (
        <span className="font-semibold text-xs text-foreground">
          {row.getValue("hostel_name")}
        </span>
      ),
    },
    {
      accessorKey: "room_number",
      header: "Room & Bed",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-foreground">
          Room {row.original.room_number} • Bed {row.original.bed_number}
        </span>
      ),
    },
    {
      accessorKey: "studentName",
      header: "Resident Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName}</p>
          <p className="text-[11px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch} Yr {row.original.year})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Occupancy",
      cell: ({ row }) => {
        const status = row.getValue("status") as string
        return (
          <StatusIndicator
            status={status === "ACTIVE" ? "success" : "neutral"}
            label={status}
            size="sm"
          />
        )
      },
    },
    {
      accessorKey: "allocated_at",
      header: "Allocated Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {formatDate(row.getValue("allocated_at"))}
        </span>
      ),
    },
  ]

  // Asset Issue columns
  const assetColumns: ColumnDef<HostelAssetIssue>[] = [
    {
      accessorKey: "assetName",
      header: "Asset",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.assetName}</p>
          <p className="text-[10px] text-muted-foreground font-mono">{row.original.assetCode}</p>
        </div>
      ),
    },
    {
      accessorKey: "roomNumber",
      header: "Location",
      cell: ({ row }) => (
        <span className="text-xs text-foreground font-mono">
          {row.original.hostelName} - Rm {row.original.roomNumber}
        </span>
      ),
    },
    {
      accessorKey: "issue_type",
      header: "Issue Type",
      cell: ({ row }) => (
        <Badge variant="warning" className="text-[10px] font-mono">
          {row.original.issue_type.replace("_", " ")}
        </Badge>
      ),
    },
    {
      accessorKey: "description",
      header: "Details",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground max-w-xs truncate block">
          {row.original.description}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => (
        <StatusIndicator status={row.original.status} label={row.original.status} size="sm" />
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <Button
          variant="outline"
          size="sm"
          onClick={() => {
            setSelectedIssue(row.original)
            setAssetActionOpen(true)
          }}
          className="text-xs h-7"
        >
          Update Status
        </Button>
      ),
    },
  ]

  // Requests columns
  const requestColumns: ColumnDef<HostelResidentRequest>[] = [
    {
      accessorKey: "studentName",
      header: "Resident",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "request_type",
      header: "Request Type",
      cell: ({ row }) => (
        <Badge variant="secondary" className="text-[10px] font-mono">
          {row.original.request_type}
        </Badge>
      ),
    },
    {
      accessorKey: "reason",
      header: "Justification",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground max-w-xs truncate block">
          {row.original.reason}
        </span>
      ),
    },
    {
      accessorKey: "status",
      header: "Status",
      cell: ({ row }) => (
        <StatusIndicator status={row.original.status} label={row.original.status} size="sm" />
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => {
        if (row.original.status === "PENDING") {
          return (
            <div className="flex items-center gap-1.5">
              <Button
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedRequest(row.original)
                  setRequestAction("APPROVE")
                  setRequestActionOpen(true)
                }}
              >
                Approve
              </Button>
              <Button
                variant="destructive"
                size="sm"
                className="h-7 text-xs"
                onClick={() => {
                  setSelectedRequest(row.original)
                  setRequestAction("REJECT")
                  setRequestActionOpen(true)
                }}
              >
                Reject
              </Button>
            </div>
          )
        }
        return <span className="text-xs text-muted-foreground font-mono">{row.original.status}</span>
      },
    },
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="Hostel Operations"
        description="Room inventory, resident bed allocations, asset maintenance work-orders, and change requests."
        badge={
          <StatusIndicator
            status="success"
            label={`${kpis?.occupancyRate ?? "92.5"}% Occupancy Rate`}
          />
        }
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              refetchAlloc()
              refetchIssues()
              refetchReqs()
            }}
            className="text-xs gap-1.5"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </Button>
        }
      />

      {/* KPI Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Resident Students</p>
          <p className="text-2xl font-bold font-mono text-foreground">{kpis?.totalResidents ?? allocations.length}</p>
          <p className="text-[11px] text-muted-foreground">Active hall allocations</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Total Tracked Assets</p>
          <p className="text-2xl font-bold font-mono text-foreground">{kpis?.totalAssets ?? "—"}</p>
          <p className="text-[11px] text-muted-foreground">Furniture & room inventory</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Damaged / In Repair</p>
          <p className="text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
            {kpis?.damagedAssets ?? assetIssues.filter((i) => i.status !== "RESOLVED" && i.status !== "CLOSED").length}
          </p>
          <p className="text-[11px] text-muted-foreground">Active maintenance issues</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Pending Requests</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {kpis?.pendingRequests ?? residentRequests.filter((r) => r.status === "PENDING").length}
          </p>
          <p className="text-[11px] text-muted-foreground">Awaiting Warden review</p>
        </div>
      </div>

      <Tabs defaultValue="allocations" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="allocations" className="text-xs gap-1.5">
            <Bed className="h-3.5 w-3.5" />
            Room Allocations ({allocations.length})
          </TabsTrigger>
          <TabsTrigger value="maintenance" className="text-xs gap-1.5">
            <Wrench className="h-3.5 w-3.5" />
            Asset Maintenance ({assetIssues.length})
          </TabsTrigger>
          <TabsTrigger value="requests" className="text-xs gap-1.5">
            <Inbox className="h-3.5 w-3.5" />
            Resident Requests ({residentRequests.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="allocations" className="space-y-4">
          <DataTable
            columns={allocationColumns}
            data={allocations}
            isLoading={isAllocLoading}
            error={allocError}
            onRetry={refetchAlloc}
            searchPlaceholder="Search resident name or room number..."
            searchColumnId="studentName"
            emptyTitle="No Allocations Found"
            emptyDescription="There are currently no active room allocations recorded in the system."
          />
        </TabsContent>

        <TabsContent value="maintenance" className="space-y-4">
          <DataTable
            columns={assetColumns}
            data={assetIssues}
            isLoading={isIssuesLoading}
            error={issuesError}
            onRetry={refetchIssues}
            searchPlaceholder="Search asset name or room..."
            searchColumnId="assetName"
            emptyTitle="No Asset Issues"
            emptyDescription="All hostel assets are in good operational condition."
          />
        </TabsContent>

        <TabsContent value="requests" className="space-y-4">
          <DataTable
            columns={requestColumns}
            data={residentRequests}
            isLoading={isReqsLoading}
            error={reqsError}
            onRetry={refetchReqs}
            searchPlaceholder="Search requests by resident name..."
            searchColumnId="studentName"
            emptyTitle="No Resident Requests"
            emptyDescription="There are no pending room transfer or leave requests."
          />
        </TabsContent>
      </Tabs>

      <ActionAssetDialog
        issue={selectedIssue}
        open={assetActionOpen}
        onOpenChange={setAssetActionOpen}
      />

      <ActionRequestDialog
        request={selectedRequest}
        action={requestAction}
        open={requestActionOpen}
        onOpenChange={setRequestActionOpen}
      />
    </div>
  )
}

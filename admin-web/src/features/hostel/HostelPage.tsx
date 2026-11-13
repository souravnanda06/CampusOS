import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { useToast } from "@/components/ui/toast"
import { ActionAssetDialog } from "./components/action-asset-dialog"
import { ActionRequestDialog } from "./components/action-request-dialog"
import { AllocateRoomDialog } from "./components/allocate-room-dialog"
import { CreateAssetDialog } from "./components/create-asset-dialog"
import {
  hostelApi,
  HostelAllocationRecord,
  HostelAssetItem,
  HostelAssetIssue,
  HostelResidentRequest,
} from "./api/hostel-api"
import { formatDate } from "@/lib/utils"
import {
  Bed,
  Wrench,
  Inbox,
  RefreshCw,
  Plus,
  Package,
  LogOut,
} from "lucide-react"

export function HostelPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [selectedIssue, setSelectedIssue] = React.useState<HostelAssetIssue | null>(null)
  const [assetActionOpen, setAssetActionOpen] = React.useState(false)

  const [selectedRequest, setSelectedRequest] = React.useState<HostelResidentRequest | null>(null)
  const [requestAction, setRequestAction] = React.useState<"APPROVE" | "REJECT" | "COMPLETE" | null>(null)
  const [requestActionOpen, setRequestActionOpen] = React.useState(false)

  const [allocateOpen, setAllocateOpen] = React.useState(false)
  const [createAssetOpen, setCreateAssetOpen] = React.useState(false)

  const { data: kpis, refetch: refetchKpis } = useQuery({
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
    data: assets = [],
    isLoading: isAssetsLoading,
    error: assetsError,
    refetch: refetchAssets,
  } = useQuery({
    queryKey: ["hostel", "assets"],
    queryFn: hostelApi.getAssets,
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

  const vacateMutation = useMutation({
    mutationFn: (id: string) => hostelApi.vacateAllocation(id),
    onSuccess: (res) => {
      toast({
        title: "Bed Vacated",
        description: res.message || "Allocation marked as vacated.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["hostel"] })
    },
    onError: (err: Error) => {
      toast({
        title: "Vacate Failed",
        description: err.message || "Unable to vacate room allocation.",
        type: "error",
      })
    },
  })

  const allocationColumns: ColumnDef<HostelAllocationRecord>[] = [
    {
      accessorKey: "hostelName",
      header: "Hostel Hall",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <span className="font-semibold text-xs text-foreground">{row.original.hostelName}</span>
          {row.original.block && (
            <p className="text-[10px] text-muted-foreground font-mono">Block {row.original.block}</p>
          )}
        </div>
      ),
    },
    {
      accessorKey: "roomNumber",
      header: "Room & Bed",
      cell: ({ row }) => (
        <span className="font-mono text-xs text-foreground">
          Room {row.original.roomNumber}
          {row.original.bedNumber ? ` • Bed ${row.original.bedNumber}` : ""}
        </span>
      ),
    },
    {
      accessorKey: "studentName",
      header: "Resident Student",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName || "Unknown"}</p>
          <p className="text-[11px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"} ({row.original.branch || "—"} Yr {row.original.year || "—"})
          </p>
        </div>
      ),
    },
    {
      accessorKey: "status",
      header: "Occupancy",
      cell: ({ row }) => {
        const status = row.original.status
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
      accessorKey: "allocatedAt",
      header: "Allocated Date",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {formatDate(row.original.allocatedAt)}
        </span>
      ),
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) =>
        row.original.status === "ACTIVE" ? (
          <Button
            variant="ghost"
            size="sm"
            className="h-7 text-xs text-rose-600 hover:text-rose-700 hover:bg-rose-500/10 gap-1"
            loading={vacateMutation.isPending && vacateMutation.variables === row.original.id}
            onClick={() => vacateMutation.mutate(row.original.id)}
          >
            <LogOut className="h-3 w-3" />
            Vacate
          </Button>
        ) : (
          <span className="text-[11px] text-muted-foreground font-mono">VACATED</span>
        ),
    },
  ]

  const inventoryColumns: ColumnDef<HostelAssetItem>[] = [
    {
      accessorKey: "assetCode",
      header: "Asset Code",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">{row.original.assetCode}</span>
      ),
    },
    {
      accessorKey: "assetName",
      header: "Item Description",
      cell: ({ row }) => (
        <span className="text-xs font-medium text-foreground">{row.original.assetName}</span>
      ),
    },
    {
      accessorKey: "roomNumber",
      header: "Location",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          {row.original.hostelName} • Rm {row.original.roomNumber}
        </span>
      ),
    },
    {
      accessorKey: "condition",
      header: "Condition",
      cell: ({ row }) => (
        <StatusIndicator status={row.original.condition} label={row.original.condition} size="sm" />
      ),
    },
    {
      accessorKey: "studentName",
      header: "Assigned Resident",
      cell: ({ row }) =>
        row.original.studentName ? (
          <div className="space-y-0.5">
            <p className="text-xs font-medium text-foreground">{row.original.studentName}</p>
            <p className="text-[10px] text-muted-foreground font-mono">{row.original.registrationNumber}</p>
          </div>
        ) : (
          <span className="text-xs text-muted-foreground">Shared / Room Fixture</span>
        ),
    },
  ]

  const assetColumns: ColumnDef<HostelAssetIssue>[] = [
    {
      accessorKey: "assetName",
      header: "Asset",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.assetName || "Asset"}</p>
          <p className="text-[10px] text-muted-foreground font-mono">{row.original.assetCode || "—"}</p>
        </div>
      ),
    },
    {
      accessorKey: "roomNumber",
      header: "Location",
      cell: ({ row }) => (
        <span className="text-xs text-foreground font-mono">
          {row.original.hostelName || "Hostel"} - Rm {row.original.roomNumber || "—"}
        </span>
      ),
    },
    {
      accessorKey: "issueType",
      header: "Issue Type",
      cell: ({ row }) => (
        <Badge variant="warning" className="text-[10px] font-mono">
          {(row.original.issueType || "ISSUE").replace(/_/g, " ")}
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

  const requestColumns: ColumnDef<HostelResidentRequest>[] = [
    {
      accessorKey: "studentName",
      header: "Resident",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.studentName || "Unknown"}</p>
          <p className="text-[10px] text-muted-foreground font-mono">
            {row.original.registrationNumber || "—"}
          </p>
        </div>
      ),
    },
    {
      accessorKey: "requestType",
      header: "Request Type",
      cell: ({ row }) => (
        <Badge variant="secondary" className="text-[10px] font-mono">
          {(row.original.requestType || "REQUEST").replace(/_/g, " ")}
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

  const occupancyDisplay =
    typeof kpis?.occupancyRate === "number" ? `${kpis.occupancyRate}% Occupancy Rate` : "Live Hostel Telemetry"

  return (
    <div className="space-y-6">
      <PageHeader
        title="Hostel Operations"
        description="Room inventory, resident bed allocations, asset maintenance work-orders, and change requests."
        badge={<StatusIndicator status="success" label={occupancyDisplay} />}
        actions={
          <div className="flex items-center gap-2 flex-wrap">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                refetchKpis()
                refetchAlloc()
                refetchAssets()
                refetchIssues()
                refetchReqs()
              }}
              className="text-xs gap-1.5"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCreateAssetOpen(true)}
              className="text-xs gap-1.5"
            >
              <Plus className="h-3.5 w-3.5" />
              Add Asset
            </Button>
            <Button size="sm" onClick={() => setAllocateOpen(true)} className="text-xs gap-1.5">
              <Bed className="h-3.5 w-3.5" />
              Allocate Room
            </Button>
          </div>
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
          <p className="text-2xl font-bold font-mono text-foreground">{kpis?.totalAssets ?? assets.length}</p>
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
          <TabsTrigger value="inventory" className="text-xs gap-1.5">
            <Package className="h-3.5 w-3.5" />
            Asset Inventory ({assets.length})
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
            searchPlaceholder="Search resident name, hall, or room number..."
            emptyTitle="No Allocations Found"
            emptyDescription="There are currently no active room allocations recorded in the system."
          />
        </TabsContent>

        <TabsContent value="inventory" className="space-y-4">
          <DataTable
            columns={inventoryColumns}
            data={assets}
            isLoading={isAssetsLoading}
            error={assetsError}
            onRetry={refetchAssets}
            searchPlaceholder="Search asset code, item, or room..."
            emptyTitle="No Inventory Registered"
            emptyDescription="Register room beds, desks, or fixtures using Add Asset."
          />
        </TabsContent>

        <TabsContent value="maintenance" className="space-y-4">
          <DataTable
            columns={assetColumns}
            data={assetIssues}
            isLoading={isIssuesLoading}
            error={issuesError}
            onRetry={refetchIssues}
            searchPlaceholder="Search asset name, issue type, or room..."
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
            searchPlaceholder="Search requests by resident name or type..."
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

      <AllocateRoomDialog open={allocateOpen} onOpenChange={setAllocateOpen} />
      <CreateAssetDialog open={createAssetOpen} onOpenChange={setCreateAssetOpen} />
    </div>
  )
}

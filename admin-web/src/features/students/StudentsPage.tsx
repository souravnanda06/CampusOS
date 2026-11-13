import * as React from "react"
import { useParams, useSearchParams, useNavigate } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { ConfirmDialog } from "@/components/feedback/confirm-dialog"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { useToast } from "@/components/ui/toast"
import { useAuth } from "@/features/auth/AuthContext"
import { StudentDetailSheet } from "./components/student-detail-sheet"
import { studentsApi, StudentRecord, StaffRecord } from "./api/students-api"
import { formatRelativeTime, resolveMediaUrl } from "@/lib/utils"
import {
  Users,
  GraduationCap,
  ExternalLink,
  UserCheck,
  CheckCircle2,
  XCircle,
  Ban,
  ZoomIn,
  UserPlus,
  Pencil,
  Trash2,
  CheckCheck,
} from "lucide-react"

export function StudentsPage() {
  const { id: routePersonId } = useParams()
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const { user: currentUser } = useAuth()

  const tabParam = searchParams.get("tab")
  const activeTab =
    tabParam && ["students", "pending", "rejected", "staff"].includes(tabParam)
      ? tabParam
      : "students"

  const [selectedStudent, setSelectedStudent] = React.useState<StudentRecord | null>(null)
  const [sheetOpen, setSheetOpen] = React.useState(false)
  const [branchFilter, setBranchFilter] = React.useState<string>("ALL")
  const [yearFilter, setYearFilter] = React.useState<string>("ALL")

  const [rejectTarget, setRejectTarget] = React.useState<StudentRecord | null>(null)
  const [rejectReason, setRejectReason] = React.useState("")
  const [photoPreviewStudent, setPhotoPreviewStudent] = React.useState<StudentRecord | null>(null)
  const [brokenImages, setBrokenImages] = React.useState<Record<string, boolean>>({})

  // Provision / Edit User Dialog state
  const [createUserOpen, setCreateUserOpen] = React.useState(false)
  const [newName, setNewName] = React.useState("")
  const [newEmail, setNewEmail] = React.useState("")
  const [newPassword, setNewPassword] = React.useState("")
  const [newRole, setNewRole] = React.useState("staff")
  const [newBranch, setNewBranch] = React.useState("")
  const [newRegNo, setNewRegNo] = React.useState("")

  const [editStaffTarget, setEditStaffTarget] = React.useState<StaffRecord | null>(null)
  const [editName, setEditName] = React.useState("")
  const [editRole, setEditRole] = React.useState("")
  const [editBranch, setEditBranch] = React.useState("")
  const [editPassword, setEditPassword] = React.useState("")

  const [deleteTarget, setDeleteTarget] = React.useState<StaffRecord | null>(null)

  const queryClient = useQueryClient()
  const { toast } = useToast()

  const handleTabChange = React.useCallback(
    (val: string) => {
      const next = new URLSearchParams(searchParams)
      if (val === "students") next.delete("tab")
      else next.set("tab", val)
      setSearchParams(next, { replace: true })
    },
    [searchParams, setSearchParams]
  )

  const {
    data: students = [],
    isLoading: isStudentsLoading,
    error: studentsError,
    refetch: refetchStudents,
  } = useQuery({
    queryKey: ["admin", "students", branchFilter, yearFilter],
    queryFn: () =>
      studentsApi.getStudentsWithStats({
        branch: branchFilter !== "ALL" ? branchFilter : undefined,
        year: yearFilter !== "ALL" ? yearFilter : undefined,
      }),
  })

  const {
    data: pendingStudents = [],
    isLoading: isPendingLoading,
    error: pendingError,
    refetch: refetchPending,
  } = useQuery({
    queryKey: ["admin", "students", "pending"],
    queryFn: studentsApi.getPendingStudents,
  })

  const {
    data: rejectedStudents = [],
    isLoading: isRejectedLoading,
    error: rejectedError,
    refetch: refetchRejected,
  } = useQuery({
    queryKey: ["admin", "students", "rejected"],
    queryFn: () => studentsApi.getAdminStudents({ approvalStatus: "REJECTED" }),
  })

  const {
    data: staff = [],
    isLoading: isStaffLoading,
    error: staffError,
    refetch: refetchStaff,
  } = useQuery({
    queryKey: ["admin", "staff"],
    queryFn: studentsApi.getStaff,
  })

  // Automatically switch to the pending tab if user lands on /people with no tab specified,
  // active students is empty, and there are registrations awaiting review
  React.useEffect(() => {
    if (!tabParam && !isStudentsLoading && !isPendingLoading && students.length === 0 && pendingStudents.length > 0) {
      handleTabChange("pending")
    }
  }, [tabParam, isStudentsLoading, isPendingLoading, students.length, pendingStudents.length, handleTabChange])

  const routeMatchedStudent = React.useMemo(() => {
    if (!routePersonId) return null
    return (
      students.find((s) => s.id === routePersonId) ||
      pendingStudents.find((s) => s.id === routePersonId) ||
      rejectedStudents.find((s) => s.id === routePersonId) ||
      null
    )
  }, [routePersonId, students, pendingStudents, rejectedStudents])

  const activeStudent = selectedStudent || routeMatchedStudent
  const isSheetOpen = sheetOpen || !!routeMatchedStudent

  const approveMutation = useMutation({
    mutationFn: (studentId: string) => studentsApi.approveStudent(studentId),
    onSuccess: (res) => {
      toast({
        title: "Account Activated",
        description: `${res.student.name}'s student account is now approved and active.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard", "summary"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Approval Failed",
        description: err instanceof Error ? err.message : "Failed to approve student registration",
        type: "error",
      })
    },
  })

  const bulkApproveMutation = useMutation({
    mutationFn: (ids: string[]) => studentsApi.bulkApproveStudents(ids),
    onSuccess: (res) => {
      toast({
        title: "Bulk Approval Completed",
        description: res.message,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard", "summary"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Bulk Approval Failed",
        description: err instanceof Error ? err.message : "Failed to bulk approve students",
        type: "error",
      })
    },
  })

  const rejectMutation = useMutation({
    mutationFn: ({ studentId, reason }: { studentId: string; reason?: string }) =>
      studentsApi.rejectStudent(studentId, reason),
    onSuccess: (res) => {
      toast({
        title: "Registration Rejected",
        description: `${res.student.name}'s registration request was rejected.`,
        type: "info",
      })
      setRejectTarget(null)
      setRejectReason("")
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "dashboard", "summary"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Rejection Failed",
        description: err instanceof Error ? err.message : "Failed to reject student registration",
        type: "error",
      })
    },
  })

  const createUserMutation = useMutation({
    mutationFn: () =>
      studentsApi.createUser({
        name: newName.trim(),
        email: newEmail.trim(),
        password: newPassword,
        role: newRole,
        branch: newBranch.trim() || undefined,
        registrationNumber: newRegNo.trim() || undefined,
      }),
    onSuccess: (res) => {
      toast({
        title: "Account Provisioned",
        description: res.message,
        type: "success",
      })
      setCreateUserOpen(false)
      setNewName("")
      setNewEmail("")
      setNewPassword("")
      setNewBranch("")
      setNewRegNo("")
      queryClient.invalidateQueries({ queryKey: ["admin", "staff"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Provisioning Failed",
        description: err instanceof Error ? err.message : "Failed to create account",
        type: "error",
      })
    },
  })

  const updateUserMutation = useMutation({
    mutationFn: () =>
      studentsApi.updateUser(editStaffTarget?.id || "", {
        name: editName.trim() || undefined,
        role: editRole || undefined,
        branch: editBranch.trim(),
        password: editPassword.trim() || undefined,
      }),
    onSuccess: (res) => {
      toast({
        title: "Account Updated",
        description: res.message,
        type: "success",
      })
      setEditStaffTarget(null)
      setEditPassword("")
      queryClient.invalidateQueries({ queryKey: ["admin", "staff"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Update Failed",
        description: err instanceof Error ? err.message : "Failed to update user",
        type: "error",
      })
    },
  })

  const deleteUserMutation = useMutation({
    mutationFn: (id: string) => studentsApi.deleteUser(id),
    onSuccess: (res) => {
      toast({
        title: "Account Removed",
        description: res.message,
        type: "info",
      })
      setDeleteTarget(null)
      queryClient.invalidateQueries({ queryKey: ["admin", "staff"] })
      queryClient.invalidateQueries({ queryKey: ["admin", "students"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Deletion Failed",
        description: err instanceof Error ? err.message : "Failed to delete user",
        type: "error",
      })
    },
  })

  const handleRowClick = (student: StudentRecord) => {
    setSelectedStudent(student)
    setSheetOpen(true)
  }

  const handleSheetOpenChange = (open: boolean) => {
    setSheetOpen(open)
    if (!open) {
      setSelectedStudent(null)
      if (routePersonId) {
        navigate("/people", { replace: true })
      }
    }
  }

  const renderPhotoThumb = (student: StudentRecord) => {
    const src = resolveMediaUrl(student.photoUrl)
    if (!src || brokenImages[student.id]) {
      return (
        <div className="h-9 w-9 shrink-0 rounded-lg border border-border bg-muted/60 flex items-center justify-center text-xs font-bold text-muted-foreground">
          {student.name?.charAt(0)?.toUpperCase() || "S"}
        </div>
      )
    }
    return (
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation()
          setPhotoPreviewStudent(student)
        }}
        className="group relative h-9 w-9 shrink-0 rounded-lg overflow-hidden border border-border bg-muted focus:outline-none focus:ring-2 focus:ring-primary"
        title="Inspect student photo"
      >
        <img
          src={src}
          alt={student.name}
          className="h-full w-full object-cover"
          onError={() => setBrokenImages((prev) => ({ ...prev, [student.id]: true }))}
        />
        <span className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <ZoomIn className="h-3.5 w-3.5 text-white" />
        </span>
      </button>
    )
  }

  const studentColumns: ColumnDef<StudentRecord>[] = [
    {
      accessorKey: "registrationNumber",
      header: "Reg Number",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {row.getValue("registrationNumber") || "—"}
        </span>
      ),
    },
    {
      accessorKey: "name",
      header: "Student",
      cell: ({ row }) => (
        <div className="flex items-center gap-2.5 min-w-[180px]">
          {renderPhotoThumb(row.original)}
          <div className="space-y-0.5 min-w-0">
            <p className="font-semibold text-xs text-foreground group-hover:text-primary transition-colors truncate">
              {row.original.name}
            </p>
            <p className="text-[11px] text-muted-foreground truncate">{row.original.email}</p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "branch",
      header: "Branch",
      cell: ({ row }) => (
        <span className="text-xs font-medium text-foreground">
          {row.getValue("branch") || "General"}
        </span>
      ),
    },
    {
      accessorKey: "year",
      header: "Year",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground font-mono">
          Yr {row.getValue("year") || "1"}
        </span>
      ),
    },
    {
      accessorKey: "attendancePercentage",
      header: "Attendance",
      cell: ({ row }) => {
        const val = (row.getValue("attendancePercentage") as number) ?? 0
        const variant = val >= 75 ? "success" : val >= 60 ? "warning" : "destructive"
        return (
          <div className="flex items-center gap-2">
            <span className="font-mono text-xs font-semibold text-foreground">{val}%</span>
            <Badge variant={variant} className="text-[10px] px-1.5 py-0">
              {val >= 75 ? "Eligible" : "Critical"}
            </Badge>
          </div>
        )
      },
    },
    {
      accessorKey: "deviceId",
      header: "Device Lock",
      cell: ({ row }) => {
        const isBound = !!row.getValue("deviceId")
        return (
          <StatusIndicator
            status={isBound ? "success" : "pending"}
            label={isBound ? "Bound" : "Unlocked"}
            size="sm"
          />
        )
      },
    },
    {
      id: "actions",
      header: "",
      cell: ({ row }) => (
        <Button
          variant="ghost"
          size="sm"
          onClick={(e) => {
            e.stopPropagation()
            handleRowClick(row.original)
          }}
          className="text-xs text-muted-foreground hover:text-foreground gap-1"
        >
          View Record
          <ExternalLink className="h-3 w-3" />
        </Button>
      ),
    },
  ]

  const pendingColumns: ColumnDef<StudentRecord>[] = [
    {
      accessorKey: "name",
      header: "Applicant & Photo",
      cell: ({ row }) => (
        <div className="flex items-center gap-3 min-w-[200px]">
          {renderPhotoThumb(row.original)}
          <div className="space-y-0.5 min-w-0">
            <p className="font-semibold text-xs text-foreground truncate">{row.original.name}</p>
            <p className="text-[11px] text-muted-foreground truncate">{row.original.email}</p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "registrationNumber",
      header: "Reg Number",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {row.getValue("registrationNumber") || "—"}
        </span>
      ),
    },
    {
      id: "academic",
      header: "Program",
      cell: ({ row }) => (
        <div className="text-xs text-foreground">
          <span className="font-medium">{row.original.course || "B.Tech"}</span>
          {row.original.branch ? ` • ${row.original.branch}` : ""}
          <span className="text-muted-foreground"> • Yr {row.original.year || "1"}</span>
        </div>
      ),
    },
    {
      accessorKey: "createdAt",
      header: "Submitted",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {formatRelativeTime(row.original.createdAt)}
        </span>
      ),
    },
    {
      id: "approvalActions",
      header: "Decision",
      cell: ({ row }) => {
        const s = row.original
        return (
          <div className="flex items-center gap-1.5" onClick={(e) => e.stopPropagation()}>
            <Button
              size="sm"
              className="h-7 px-2.5 text-xs gap-1"
              disabled={approveMutation.isPending || rejectMutation.isPending}
              onClick={() => approveMutation.mutate(s.id)}
            >
              <CheckCircle2 className="h-3.5 w-3.5" />
              Approve
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="h-7 px-2.5 text-xs gap-1 text-destructive hover:text-destructive border-destructive/30 hover:bg-destructive/10"
              disabled={approveMutation.isPending || rejectMutation.isPending}
              onClick={() => {
                setRejectTarget(s)
                setRejectReason("")
              }}
            >
              <XCircle className="h-3.5 w-3.5" />
              Reject
            </Button>
          </div>
        )
      },
    },
  ]

  const rejectedColumns: ColumnDef<StudentRecord>[] = [
    {
      accessorKey: "name",
      header: "Student & Photo",
      cell: ({ row }) => (
        <div className="flex items-center gap-3 min-w-[200px]">
          {renderPhotoThumb(row.original)}
          <div className="space-y-0.5 min-w-0">
            <p className="font-semibold text-xs text-foreground truncate">{row.original.name}</p>
            <p className="text-[11px] text-muted-foreground truncate">{row.original.email}</p>
          </div>
        </div>
      ),
    },
    {
      accessorKey: "registrationNumber",
      header: "Reg Number",
      cell: ({ row }) => (
        <span className="font-mono text-xs font-semibold text-foreground">
          {row.getValue("registrationNumber") || "—"}
        </span>
      ),
    },
    {
      accessorKey: "rejectionReason",
      header: "Rejection Reason",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {row.original.rejectionReason || "No reason provided"}
        </span>
      ),
    },
    {
      id: "reapprove",
      header: "Action",
      cell: ({ row }) => (
        <div onClick={(e) => e.stopPropagation()}>
          <Button
            variant="outline"
            size="sm"
            className="h-7 px-2.5 text-xs gap-1"
            disabled={approveMutation.isPending}
            onClick={() => approveMutation.mutate(row.original.id)}
          >
            <CheckCircle2 className="h-3.5 w-3.5" />
            Approve &amp; Activate
          </Button>
        </div>
      ),
    },
  ]

  const staffColumns: ColumnDef<StaffRecord>[] = [
    {
      accessorKey: "name",
      header: "Staff Member",
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="font-semibold text-xs text-foreground">{row.original.name}</p>
          <p className="text-[11px] text-muted-foreground">{row.original.email}</p>
        </div>
      ),
    },
    {
      accessorKey: "role",
      header: "Institutional Role",
      cell: ({ row }) => {
        const role = row.getValue("role") as string
        return (
          <Badge variant="outline" className="capitalize text-xs font-mono">
            {role.replace("_", " ")}
          </Badge>
        )
      },
    },
    {
      accessorKey: "branch",
      header: "Department / Affiliation",
      cell: ({ row }) => (
        <span className="text-xs text-muted-foreground">
          {row.getValue("branch") || row.original.course || "Campus Operations"}
        </span>
      ),
    },
    {
      id: "staffActions",
      header: "",
      cell: ({ row }) => {
        const member = row.original
        const isSelf = member.id === currentUser?.id
        return (
          <div className="flex items-center justify-end gap-1">
            <Button
              variant="ghost"
              size="sm"
              className="h-7 px-2 text-xs gap-1"
              onClick={() => {
                setEditStaffTarget(member)
                setEditName(member.name)
                setEditRole(member.role)
                setEditBranch(member.branch || "")
                setEditPassword("")
              }}
            >
              <Pencil className="h-3 w-3" /> Edit Role
            </Button>
            {!isSelf && (
              <Button
                variant="ghost"
                size="sm"
                className="h-7 px-2 text-xs text-destructive hover:bg-destructive/10"
                onClick={() => setDeleteTarget(member)}
              >
                <Trash2 className="h-3 w-3" />
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
        title="People & Role Directory"
        description="Student registry, registration photo verification, bulk account activation, and institutional staff provisioning."
        badge={
          <div className="flex items-center gap-2">
            <span className="text-xs font-mono text-muted-foreground">
              {students.length} Active Students
            </span>
            {pendingStudents.length > 0 && (
              <Badge variant="warning" className="text-[11px]">
                {pendingStudents.length} Pending Approval
              </Badge>
            )}
          </div>
        }
        actions={
          <Button size="sm" onClick={() => setCreateUserOpen(true)} className="text-xs gap-1.5">
            <UserPlus className="h-3.5 w-3.5" />
            Provision Account
          </Button>
        }
      />

      <Tabs value={activeTab} onValueChange={handleTabChange} className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="students" className="text-xs gap-1.5">
            <GraduationCap className="h-3.5 w-3.5" />
            Students Directory ({students.length})
          </TabsTrigger>
          <TabsTrigger value="pending" className="text-xs gap-1.5">
            <UserCheck className="h-3.5 w-3.5" />
            Pending Approvals
            {pendingStudents.length > 0 ? (
              <Badge variant="warning" className="ml-1 px-1.5 py-0 text-[10px]">
                {pendingStudents.length}
              </Badge>
            ) : (
              <span className="text-muted-foreground">(0)</span>
            )}
          </TabsTrigger>
          <TabsTrigger value="rejected" className="text-xs gap-1.5">
            <Ban className="h-3.5 w-3.5" />
            Rejected ({rejectedStudents.length})
          </TabsTrigger>
          <TabsTrigger value="staff" className="text-xs gap-1.5">
            <Users className="h-3.5 w-3.5" />
            Staff &amp; Faculty ({staff.length})
          </TabsTrigger>
        </TabsList>

        <TabsContent value="students" className="space-y-4">
          {pendingStudents.length > 0 && (
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 p-3.5 rounded-xl border border-amber-500/30 bg-amber-500/10 text-amber-950 dark:text-amber-100 shadow-xs">
              <div className="flex items-center gap-3 min-w-0">
                <div className="h-9 w-9 shrink-0 rounded-lg bg-amber-500/20 flex items-center justify-center text-amber-600 dark:text-amber-400">
                  <UserCheck className="h-5 w-5" />
                </div>
                <div className="space-y-0.5 min-w-0">
                  <p className="text-xs font-bold tracking-tight text-amber-900 dark:text-amber-200">
                    {pendingStudents.length} Student Registration{pendingStudents.length > 1 ? "s" : ""} Awaiting Review
                  </p>
                  <p className="text-[11px] text-amber-800/80 dark:text-amber-300/80">
                    New student accounts remain inactive and cannot access CampusOS services until approved.
                  </p>
                </div>
              </div>
              <Button
                size="sm"
                className="h-8 px-3 text-xs gap-1.5 shrink-0 bg-amber-600 hover:bg-amber-700 text-white dark:bg-amber-500 dark:hover:bg-amber-600 dark:text-black font-semibold shadow-xs"
                onClick={() => handleTabChange("pending")}
              >
                <UserCheck className="h-3.5 w-3.5" />
                Review Pending ({pendingStudents.length}) &rarr;
              </Button>
            </div>
          )}

          <DataTable
            columns={studentColumns}
            data={students}
            isLoading={isStudentsLoading}
            error={studentsError}
            onRetry={refetchStudents}
            searchPlaceholder="Search student by name, email, or reg #..."
            onRowClick={handleRowClick}
            emptyTitle="No Active Students Found"
            emptyDescription="No approved student records matched the specified department or search filter."
            toolbarSlot={
              <div className="flex items-center gap-2">
                <Select value={branchFilter} onValueChange={setBranchFilter}>
                  <SelectTrigger className="w-32 h-8 text-xs bg-card">
                    <SelectValue placeholder="Branch" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">All Branches</SelectItem>
                    <SelectItem value="CSE">CSE</SelectItem>
                    <SelectItem value="ECE">ECE</SelectItem>
                    <SelectItem value="MECH">MECH</SelectItem>
                    <SelectItem value="CIVIL">CIVIL</SelectItem>
                  </SelectContent>
                </Select>

                <Select value={yearFilter} onValueChange={setYearFilter}>
                  <SelectTrigger className="w-28 h-8 text-xs bg-card">
                    <SelectValue placeholder="Year" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="ALL">All Years</SelectItem>
                    <SelectItem value="1st">Year 1</SelectItem>
                    <SelectItem value="2nd">Year 2</SelectItem>
                    <SelectItem value="3rd">Year 3</SelectItem>
                    <SelectItem value="4th">Year 4</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            }
          />
        </TabsContent>

        <TabsContent value="pending" className="space-y-4">
          <DataTable
            columns={pendingColumns}
            data={pendingStudents}
            isLoading={isPendingLoading}
            error={pendingError}
            onRetry={refetchPending}
            searchPlaceholder="Search pending applicants..."
            onRowClick={handleRowClick}
            emptyTitle="No Pending Registrations"
            emptyDescription="All student registration requests have been reviewed."
            toolbarSlot={
              pendingStudents.length > 0 ? (
                <Button
                  size="sm"
                  className="h-8 text-xs gap-1.5"
                  loading={bulkApproveMutation.isPending}
                  onClick={() => bulkApproveMutation.mutate(pendingStudents.map((s) => s.id))}
                >
                  <CheckCheck className="h-3.5 w-3.5" />
                  Approve All ({pendingStudents.length})
                </Button>
              ) : null
            }
          />
        </TabsContent>

        <TabsContent value="rejected" className="space-y-4">
          <DataTable
            columns={rejectedColumns}
            data={rejectedStudents}
            isLoading={isRejectedLoading}
            error={rejectedError}
            onRetry={refetchRejected}
            searchPlaceholder="Search rejected registrations..."
            onRowClick={handleRowClick}
            emptyTitle="No Rejected Registrations"
            emptyDescription="No student registration requests have been rejected."
          />
        </TabsContent>

        <TabsContent value="staff" className="space-y-4">
          <DataTable
            columns={staffColumns}
            data={staff}
            isLoading={isStaffLoading}
            error={staffError}
            onRetry={refetchStaff}
            searchPlaceholder="Search faculty, warden, security, or admin..."
            emptyTitle="No Staff Records"
            emptyDescription="There are currently no staff accounts returned by the institutional directory."
          />
        </TabsContent>
      </Tabs>

      <StudentDetailSheet
        student={activeStudent}
        open={isSheetOpen}
        onOpenChange={handleSheetOpenChange}
        onStudentUpdated={(updated) => setSelectedStudent(updated)}
      />

      {/* Provision User / Staff Dialog */}
      <Dialog open={createUserOpen} onOpenChange={setCreateUserOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Provision Institutional Account</DialogTitle>
            <DialogDescription>
              Create a verified staff, faculty, warden, security, mess, admin, or student account.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3 py-2 text-xs">
            <div className="space-y-1">
              <label className="font-medium text-foreground">Full Name *</label>
              <Input value={newName} onChange={(e) => setNewName(e.target.value)} placeholder="Dr. Priya Sharma" className="h-8 text-xs" />
            </div>
            <div className="space-y-1">
              <label className="font-medium text-foreground">Institutional Email *</label>
              <Input value={newEmail} onChange={(e) => setNewEmail(e.target.value)} placeholder="priya.sharma@campusos.edu" className="h-8 text-xs" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="font-medium text-foreground">Role *</label>
                <Select value={newRole} onValueChange={setNewRole}>
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="admin">Admin / Dean</SelectItem>
                    <SelectItem value="warden">Hostel Warden</SelectItem>
                    <SelectItem value="teacher">Faculty / Teacher</SelectItem>
                    <SelectItem value="staff">Institutional Staff</SelectItem>
                    <SelectItem value="security">Gate Security</SelectItem>
                    <SelectItem value="mess_staff">Mess Manager</SelectItem>
                    <SelectItem value="student">Student (Pre-approved)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <label className="font-medium text-foreground">Department / Branch</label>
                <Input value={newBranch} onChange={(e) => setNewBranch(e.target.value)} placeholder="CSE / Hostel" className="h-8 text-xs" />
              </div>
            </div>
            {newRole === "student" && (
              <div className="space-y-1">
                <label className="font-medium text-foreground">Registration Number</label>
                <Input value={newRegNo} onChange={(e) => setNewRegNo(e.target.value)} placeholder="2026BPUT001" className="h-8 text-xs font-mono" />
              </div>
            )}
            <div className="space-y-1">
              <label className="font-medium text-foreground">Initial Password *</label>
              <Input type="password" value={newPassword} onChange={(e) => setNewPassword(e.target.value)} placeholder="Minimum 6 characters" className="h-8 text-xs" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" size="sm" onClick={() => setCreateUserOpen(false)}>Cancel</Button>
            <Button
              size="sm"
              disabled={!newName.trim() || !newEmail.trim() || newPassword.length < 4}
              loading={createUserMutation.isPending}
              onClick={() => createUserMutation.mutate()}
            >
              Create Account
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Staff / Role Dialog */}
      <Dialog open={!!editStaffTarget} onOpenChange={(open) => !open && setEditStaffTarget(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Edit Account &amp; Role</DialogTitle>
            <DialogDescription>{editStaffTarget?.email}</DialogDescription>
          </DialogHeader>
          <div className="space-y-3 py-2 text-xs">
            <div className="space-y-1">
              <label className="font-medium text-foreground">Name</label>
              <Input value={editName} onChange={(e) => setEditName(e.target.value)} className="h-8 text-xs" />
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1">
                <label className="font-medium text-foreground">Role</label>
                <Select value={editRole} onValueChange={setEditRole}>
                  <SelectTrigger className="h-8 text-xs">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="admin">Admin</SelectItem>
                    <SelectItem value="warden">Warden</SelectItem>
                    <SelectItem value="teacher">Teacher</SelectItem>
                    <SelectItem value="faculty">Faculty</SelectItem>
                    <SelectItem value="staff">Staff</SelectItem>
                    <SelectItem value="security">Security</SelectItem>
                    <SelectItem value="mess_staff">Mess Staff</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1">
                <label className="font-medium text-foreground">Department</label>
                <Input value={editBranch} onChange={(e) => setEditBranch(e.target.value)} className="h-8 text-xs" />
              </div>
            </div>
            <div className="space-y-1">
              <label className="font-medium text-foreground">Reset Password (Optional)</label>
              <Input
                type="password"
                value={editPassword}
                onChange={(e) => setEditPassword(e.target.value)}
                placeholder="Leave blank to keep unchanged"
                className="h-8 text-xs"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" size="sm" onClick={() => setEditStaffTarget(null)}>Cancel</Button>
            <Button size="sm" loading={updateUserMutation.isPending} onClick={() => updateUserMutation.mutate()}>
              Save Changes
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <ConfirmDialog
        open={!!deleteTarget}
        onOpenChange={(open) => !open && setDeleteTarget(null)}
        title="Delete Staff Account"
        description={`Remove ${deleteTarget?.name} (${deleteTarget?.email}) from CampusOS? This action is audited and irreversible.`}
        confirmLabel="Delete Account"
        variant="destructive"
        isLoading={deleteUserMutation.isPending}
        onConfirm={() => {
          if (deleteTarget) deleteUserMutation.mutate(deleteTarget.id)
        }}
      />

      {/* Reject Registration Dialog */}
      <Dialog
        open={!!rejectTarget}
        onOpenChange={(open) => {
          if (!open) {
            setRejectTarget(null)
            setRejectReason("")
          }
        }}
      >
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Reject Student Registration</DialogTitle>
            <DialogDescription>
              Provide an optional reason for rejecting {rejectTarget?.name}&apos;s registration request.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-2">
            <Input
              placeholder="e.g. Photo is blurry or registration number is invalid"
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" size="sm" onClick={() => setRejectTarget(null)} disabled={rejectMutation.isPending}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              size="sm"
              disabled={rejectMutation.isPending}
              onClick={() =>
                rejectTarget &&
                rejectMutation.mutate({
                  studentId: rejectTarget.id,
                  reason: rejectReason.trim() || undefined,
                })
              }
            >
              {rejectMutation.isPending ? "Rejecting..." : "Confirm Rejection"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Photo Preview Lightbox */}
      <Dialog open={!!photoPreviewStudent} onOpenChange={(open) => !open && setPhotoPreviewStudent(null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>{photoPreviewStudent?.name}</DialogTitle>
            <DialogDescription>
              {photoPreviewStudent?.registrationNumber || photoPreviewStudent?.email} — Submitted Registration Photo
            </DialogDescription>
          </DialogHeader>
          {photoPreviewStudent?.photoUrl && (
            <div className="overflow-hidden rounded-xl border border-border bg-muted/40">
              <img
                src={resolveMediaUrl(photoPreviewStudent.photoUrl) || ""}
                alt={photoPreviewStudent.name}
                className="w-full max-h-[65vh] object-contain"
              />
            </div>
          )}
          {photoPreviewStudent?.approvalStatus === "PENDING" && (
            <DialogFooter>
              <Button
                variant="outline"
                size="sm"
                className="text-destructive border-destructive/30 hover:bg-destructive/10"
                disabled={approveMutation.isPending || rejectMutation.isPending}
                onClick={() => {
                  const target = photoPreviewStudent
                  setPhotoPreviewStudent(null)
                  setRejectTarget(target)
                }}
              >
                <XCircle className="h-3.5 w-3.5 mr-1" />
                Reject
              </Button>
              <Button
                size="sm"
                disabled={approveMutation.isPending || rejectMutation.isPending}
                onClick={() => {
                  const id = photoPreviewStudent.id
                  setPhotoPreviewStudent(null)
                  approveMutation.mutate(id)
                }}
              >
                <CheckCircle2 className="h-3.5 w-3.5 mr-1" />
                Approve &amp; Activate
              </Button>
            </DialogFooter>
          )}
        </DialogContent>
      </Dialog>
    </div>
  )
}

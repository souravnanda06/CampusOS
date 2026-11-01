import * as React from "react"
import { useParams } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
import { ColumnDef } from "@tanstack/react-table"
import { PageHeader } from "@/components/ui/page-header"
import { DataTable } from "@/components/data-table/data-table"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { StudentDetailSheet } from "./components/student-detail-sheet"
import { studentsApi, StudentRecord, StaffRecord } from "./api/students-api"
import { Users, GraduationCap, ShieldCheck, Smartphone, ExternalLink } from "lucide-react"

export function StudentsPage() {
  const { id: routePersonId } = useParams()
  const [selectedStudent, setSelectedStudent] = React.useState<StudentRecord | null>(null)
  const [sheetOpen, setSheetOpen] = React.useState(false)
  const [branchFilter, setBranchFilter] = React.useState<string>("ALL")
  const [yearFilter, setYearFilter] = React.useState<string>("ALL")

  // Fetch Students with Stats
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

  // Fetch Staff Directory
  const {
    data: staff = [],
    isLoading: isStaffLoading,
    error: staffError,
    refetch: refetchStaff,
  } = useQuery({
    queryKey: ["admin", "staff"],
    queryFn: studentsApi.getStaff,
  })

  React.useEffect(() => {
    if (routePersonId && students.length > 0) {
      const match = students.find((s) => s.id === routePersonId)
      if (match) {
        setSelectedStudent(match)
        setSheetOpen(true)
      }
    }
  }, [routePersonId, students])

  const handleRowClick = (student: StudentRecord) => {
    setSelectedStudent(student)
    setSheetOpen(true)
  }

  // Student table columns
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
      header: "Student Name",
      cell: ({ row }) => (
        <div className="space-y-0.5 min-w-[140px]">
          <p className="font-semibold text-xs text-foreground group-hover:text-primary transition-colors">
            {row.original.name}
          </p>
          <p className="text-[11px] text-muted-foreground">{row.original.email}</p>
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
        const val = row.getValue("attendancePercentage") as number ?? 0
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

  // Staff table columns
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
  ]

  return (
    <div className="space-y-6">
      <PageHeader
        title="People Directory"
        description="Comprehensive management of campus students, verified device identity locks, and institutional staff."
        badge={
          <span className="text-xs font-mono text-muted-foreground">
            {students.length} Enrolled Students
          </span>
        }
      />

      <Tabs defaultValue="students" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="students" className="text-xs gap-1.5">
            <GraduationCap className="h-3.5 w-3.5" />
            Students Directory ({students.length})
          </TabsTrigger>
          <TabsTrigger value="staff" className="text-xs gap-1.5">
            <Users className="h-3.5 w-3.5" />
            Staff & Faculty ({staff.length})
          </TabsTrigger>
        </TabsList>

        {/* STUDENTS TAB */}
        <TabsContent value="students" className="space-y-4">
          <DataTable
            columns={studentColumns}
            data={students}
            isLoading={isStudentsLoading}
            error={studentsError}
            onRetry={refetchStudents}
            searchPlaceholder="Search student by name or registration..."
            searchColumnId="name"
            onRowClick={handleRowClick}
            emptyTitle="No Students Found"
            emptyDescription="No active student records matched the specified department or search filter."
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
                    <SelectItem value="1">Year 1</SelectItem>
                    <SelectItem value="2">Year 2</SelectItem>
                    <SelectItem value="3">Year 3</SelectItem>
                    <SelectItem value="4">Year 4</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            }
          />
        </TabsContent>

        {/* STAFF TAB */}
        <TabsContent value="staff" className="space-y-4">
          <DataTable
            columns={staffColumns}
            data={staff}
            isLoading={isStaffLoading}
            error={staffError}
            onRetry={refetchStaff}
            searchPlaceholder="Search faculty or administrative staff..."
            searchColumnId="name"
            emptyTitle="No Staff Records"
            emptyDescription="There are currently no staff accounts returned by the institutional directory."
          />
        </TabsContent>
      </Tabs>

      {/* Student Detail Slide-Over Sheet */}
      <StudentDetailSheet
        student={selectedStudent}
        open={sheetOpen}
        onOpenChange={setSheetOpen}
      />
    </div>
  )
}

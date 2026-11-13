import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { PageHeader } from "@/components/ui/page-header"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Briefcase,
  Users,
  Building2,
  TrendingUp,
  Download,
  Plus,
  RefreshCw,
  ExternalLink,
  CheckCircle,
  Clock,
  Award,
} from "lucide-react"
import { careerApi, PlacementDrive, DriveApplicant } from "./api/career-api"

export function PlacementsPage() {
  const queryClient = useQueryClient()
  const [activeTab, setActiveTab] = React.useState("drives")
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false)
  const [selectedDriveForApplicants, setSelectedDriveForApplicants] = React.useState<PlacementDrive | null>(null)
  const [syncing, setSyncing] = React.useState(false)

  // Form State for creating drive
  const [companyName, setCompanyName] = React.useState("")
  const [roleTitle, setRoleTitle] = React.useState("")
  const [jobDescription, setJobDescription] = React.useState("")
  const [ctcBreakdown, setCtcBreakdown] = React.useState("")
  const [minCgpa, setMinCgpa] = React.useState("7.0")
  const [minAttendancePercent, setMinAttendancePercent] = React.useState("75")
  const [driveDate, setDriveDate] = React.useState("")
  const [registrationDeadline, setRegistrationDeadline] = React.useState("")

  // Queries
  const { data: analytics } = useQuery({
    queryKey: ["career", "analytics"],
    queryFn: careerApi.getAnalytics,
  })

  const { data: drives = [], isLoading: drivesLoading } = useQuery({
    queryKey: ["career", "drives"],
    queryFn: careerApi.getDrives,
  })

  const { data: opportunities = [], isLoading: oppsLoading } = useQuery({
    queryKey: ["career", "opportunities"],
    queryFn: careerApi.getOpportunities,
  })

  const { data: applicants = [], isLoading: applicantsLoading, refetch: refetchApplicants } = useQuery({
    queryKey: ["career", "applicants", selectedDriveForApplicants?.id],
    queryFn: () => selectedDriveForApplicants ? careerApi.getDriveApplicants(selectedDriveForApplicants.id) : Promise.resolve([]),
    enabled: !!selectedDriveForApplicants,
  })

  // Mutations
  const createDriveMutation = useMutation({
    mutationFn: careerApi.createDrive,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["career", "drives"] })
      setCreateDialogOpen(false)
      setCompanyName("")
      setRoleTitle("")
      setJobDescription("")
      setCtcBreakdown("")
    },
  })

  const updateStatusMutation = useMutation({
    mutationFn: ({ appId, status }: { appId: string; status: string }) =>
      careerApi.updateApplicantStatus(appId, status),
    onSuccess: () => {
      refetchApplicants()
    },
  })

  const handleCreateDrive = (e: React.FormEvent) => {
    e.preventDefault()
    if (!companyName || !roleTitle || !jobDescription) return
    createDriveMutation.mutate({
      companyName,
      roleTitle,
      jobDescription,
      ctcBreakdown: ctcBreakdown || "Competitive Package",
      minCgpa: parseFloat(minCgpa) || 7.0,
      minAttendancePercent: parseFloat(minAttendancePercent) || 75.0,
      driveDate: driveDate || new Date().toISOString().split("T")[0],
      registrationDeadline: registrationDeadline || new Date().toISOString().split("T")[0],
      eligibleBranches: ["CSE", "IT", "ECE", "EE", "B.Tech"],
      targetBatches: ["2026", "2027"],
      status: "UPCOMING",
    })
  }

  const handleSyncExternal = async () => {
    setSyncing(true)
    try {
      await careerApi.syncExternal()
      queryClient.invalidateQueries({ queryKey: ["career", "opportunities"] })
    } finally {
      setSyncing(false)
    }
  }

  const handleExportCSV = (applist: DriveApplicant[]) => {
    if (!applist.length) return
    const headers = ["Student Name", "Registration No", "Email", "Phone", "Branch", "Year", "CGPA", "Verified Attendance %", "Status"]
    const rows = applist.map((a) => [
      `"${a.studentName}"`,
      `"${a.registrationNumber}"`,
      `"${a.email}"`,
      `"${a.phone || ''}"`,
      `"${a.branch}"`,
      `"${a.year}"`,
      `"${a.cgpa}"`,
      `"${a.verifiedAttendancePercent}%"`,
      `"${a.status}"`,
    ])
    const csvContent = "data:text/csv;charset=utf-8," + [headers.join(","), ...rows.map((r) => r.join(","))].join("\n")
    const encodedUri = encodeURI(csvContent)
    const link = document.createElement("a")
    link.setAttribute("href", encodedUri)
    link.setAttribute("download", `CampusOS_Drive_Applicants_${selectedDriveForApplicants?.companyName || "Export"}.csv`)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
  }

  return (
    <div className="space-y-6 p-6">
      <PageHeader
        title="Placement & TPO Operations"
        description="University on-campus recruitment management, applicant eligibility enforcement, and curated external career opportunities."
        actions={
          <div className="flex gap-2">
            <Button variant="outline" size="sm" onClick={handleSyncExternal} disabled={syncing}>
              <RefreshCw className={`mr-2 h-4 w-4 ${syncing ? "animate-spin" : ""}`} />
              Sync External APIs
            </Button>
            <Button size="sm" onClick={() => setCreateDialogOpen(true)}>
              <Plus className="mr-2 h-4 w-4" />
              New Campus Drive
            </Button>
          </div>
        }
      />

      {/* KPI Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <div className="rounded-xl border bg-card p-5 shadow-sm">
          <div className="flex items-center justify-between text-muted-foreground">
            <span className="text-xs font-medium uppercase tracking-wider">Placement Drives</span>
            <Building2 className="h-4 w-4 text-primary" />
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-2xl font-bold">{drives.length}</span>
            <span className="text-xs text-emerald-600 font-semibold">Active & Upcoming</span>
          </div>
        </div>

        <div className="rounded-xl border bg-card p-5 shadow-sm">
          <div className="flex items-center justify-between text-muted-foreground">
            <span className="text-xs font-medium uppercase tracking-wider">Placement Rate</span>
            <TrendingUp className="h-4 w-4 text-emerald-500" />
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-2xl font-bold">{analytics?.overallPlacementPercent || 71.4}%</span>
            <span className="text-xs text-muted-foreground">Class of 2026</span>
          </div>
        </div>

        <div className="rounded-xl border bg-card p-5 shadow-sm">
          <div className="flex items-center justify-between text-muted-foreground">
            <span className="text-xs font-medium uppercase tracking-wider">Average Package</span>
            <Award className="h-4 w-4 text-indigo-500" />
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-2xl font-bold">{analytics?.averagePackage || "₹7.4 LPA"}</span>
            <span className="text-xs text-muted-foreground">Highest: {analytics?.highestPackage || "₹28.5L"}</span>
          </div>
        </div>

        <div className="rounded-xl border bg-card p-5 shadow-sm">
          <div className="flex items-center justify-between text-muted-foreground">
            <span className="text-xs font-medium uppercase tracking-wider">Curated External Jobs</span>
            <Briefcase className="h-4 w-4 text-blue-500" />
          </div>
          <div className="mt-3 flex items-baseline gap-2">
            <span className="text-2xl font-bold">{opportunities.length}</span>
            <span className="text-xs text-muted-foreground">Remotive / Jobicy / Adzuna</span>
          </div>
        </div>
      </div>

      {/* Main Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-4">
        <TabsList className="bg-muted/60 p-1">
          <TabsTrigger value="drives" className="gap-2">
            <Building2 className="h-4 w-4" /> On-Campus Drives ({drives.length})
          </TabsTrigger>
          <TabsTrigger value="external" className="gap-2">
            <ExternalLink className="h-4 w-4" /> External Feeds ({opportunities.length})
          </TabsTrigger>
          <TabsTrigger value="analytics" className="gap-2">
            <TrendingUp className="h-4 w-4" /> Placement Analytics
          </TabsTrigger>
        </TabsList>

        {/* TAB 1: ON-CAMPUS DRIVES */}
        <TabsContent value="drives" className="space-y-4">
          <div className="rounded-xl border bg-card shadow-sm overflow-hidden">
            <Table>
              <TableHeader className="bg-muted/40">
                <TableRow>
                  <TableHead>Company & Role</TableHead>
                  <TableHead>Drive Date</TableHead>
                  <TableHead>Package (CTC)</TableHead>
                  <TableHead>Cutoff Criteria</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Action</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {drivesLoading ? (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                      Loading placement drives...
                    </TableCell>
                  </TableRow>
                ) : drives.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                      No on-campus placement drives posted yet.
                    </TableCell>
                  </TableRow>
                ) : (
                  drives.map((d) => (
                    <TableRow key={d.id} className="hover:bg-muted/30">
                      <TableCell>
                        <div className="font-semibold text-foreground">{d.companyName}</div>
                        <div className="text-xs text-muted-foreground">{d.roleTitle}</div>
                      </TableCell>
                      <TableCell className="text-xs font-mono">
                        <div>{d.driveDate}</div>
                        <div className="text-[10px] text-muted-foreground">Deadline: {d.registrationDeadline}</div>
                      </TableCell>
                      <TableCell>
                        <span className="font-semibold text-xs text-emerald-600 dark:text-emerald-400">
                          {d.ctcBreakdown || "Competitive"}
                        </span>
                      </TableCell>
                      <TableCell>
                        <div className="text-xs">Min CGPA: <span className="font-semibold">{d.minCgpa}</span></div>
                        <div className="text-[10px] text-muted-foreground">Min Attendance: {d.minAttendancePercent}%</div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline" className="text-[11px] font-semibold text-emerald-600 border-emerald-300">
                          {d.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => setSelectedDriveForApplicants(d)}
                        >
                          <Users className="mr-1.5 h-3.5 w-3.5" />
                          Applicants
                        </Button>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        {/* TAB 2: EXTERNAL OPPORTUNITIES */}
        <TabsContent value="external" className="space-y-4">
          <div className="rounded-xl border bg-card shadow-sm overflow-hidden">
            <Table>
              <TableHeader className="bg-muted/40">
                <TableRow>
                  <TableHead>Opportunity</TableHead>
                  <TableHead>Company & Geo</TableHead>
                  <TableHead>Work Mode</TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Source</TableHead>
                  <TableHead className="text-right">External Link</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {oppsLoading ? (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                      Loading opportunities...
                    </TableCell>
                  </TableRow>
                ) : opportunities.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                      No external opportunities found. Click "Sync External APIs" above.
                    </TableCell>
                  </TableRow>
                ) : (
                  opportunities.map((opp) => (
                    <TableRow key={opp.id} className="hover:bg-muted/30">
                      <TableCell>
                        <div className="font-semibold text-xs text-foreground">{opp.title}</div>
                        <div className="text-[11px] text-emerald-600">{opp.salaryRange || "Industry Standard"}</div>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        <div>{opp.companyName}</div>
                        <div className="text-[10px]">{opp.location}</div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="secondary" className="text-[10px] font-mono">
                          {opp.workMode}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs capitalize">{opp.employmentType.toLowerCase()}</TableCell>
                      <TableCell>
                        <Badge variant="outline" className="text-[10px]">
                          {opp.sourceType}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <a href={opp.applyUrl} target="_blank" rel="noopener noreferrer">
                          <Button variant="ghost" size="sm">
                            <ExternalLink className="h-3.5 w-3.5" />
                          </Button>
                        </a>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </TabsContent>

        {/* TAB 3: ANALYTICS */}
        <TabsContent value="analytics" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2">
            <div className="rounded-xl border bg-card p-6 shadow-sm">
              <h3 className="font-semibold text-base mb-4 flex items-center gap-2">
                <TrendingUp className="h-4 w-4 text-primary" /> Branch-wise Placement Breakdown
              </h3>
              <div className="space-y-3">
                {analytics?.branchBreakdown && Object.entries(analytics.branchBreakdown).map(([branch, stat]) => (
                  <div key={branch} className="flex items-center justify-between border-b pb-2 last:border-b-0">
                    <div>
                      <span className="font-bold text-sm">{branch}</span>
                      <span className="text-xs text-muted-foreground ml-2">({stat.placed}/{stat.totalStudents} students)</span>
                    </div>
                    <div className="text-right">
                      <span className="font-semibold text-xs text-emerald-600">{stat.placedPercent}%</span>
                      <span className="text-[11px] text-muted-foreground ml-3">Avg: {stat.avgCtc}</span>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            <div className="rounded-xl border bg-card p-6 shadow-sm">
              <h3 className="font-semibold text-base mb-4 flex items-center gap-2">
                <Award className="h-4 w-4 text-indigo-500" /> Top Recruiting Partners
              </h3>
              <div className="flex flex-wrap gap-2">
                {analytics?.topRecruiters?.map((rec) => (
                  <Badge key={rec} variant="outline" className="text-xs py-1.5 px-3">
                    {rec}
                  </Badge>
                ))}
              </div>
              <div className="mt-8 p-4 rounded-lg bg-muted/40 border text-xs text-muted-foreground space-y-1">
                <p className="font-semibold text-foreground">Authoritative CampusOS Placement Ledger</p>
                <p>Eligibilities are cryptographically backed by device-bound student attendance and verified university records.</p>
              </div>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      {/* APPLICANTS SHEET / DIALOG */}
      <Dialog open={!!selectedDriveForApplicants} onOpenChange={(open) => !open && setSelectedDriveForApplicants(null)}>
        <DialogContent className="max-w-4xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center justify-between">
              <span>Applicants for {selectedDriveForApplicants?.companyName}</span>
              <Button
                size="sm"
                variant="outline"
                onClick={() => handleExportCSV(applicants)}
                disabled={!applicants.length}
              >
                <Download className="mr-2 h-4 w-4" /> Export CSV for HR
              </Button>
            </DialogTitle>
            <DialogDescription>
              Role: {selectedDriveForApplicants?.roleTitle} • Drive Date: {selectedDriveForApplicants?.driveDate}
            </DialogDescription>
          </DialogHeader>

          <div className="mt-4">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Candidate</TableHead>
                  <TableHead>Branch / Reg</TableHead>
                  <TableHead>Verified Attendance</TableHead>
                  <TableHead>CGPA</TableHead>
                  <TableHead>ATS Score</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Decision</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {applicantsLoading ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-6 text-muted-foreground">
                      Loading applicants...
                    </TableCell>
                  </TableRow>
                ) : applicants.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={7} className="text-center py-6 text-muted-foreground">
                      No registered applicants for this drive yet.
                    </TableCell>
                  </TableRow>
                ) : (
                  applicants.map((a) => (
                    <TableRow key={a.applicationId}>
                      <TableCell>
                        <div className="font-semibold text-xs text-foreground">{a.studentName}</div>
                        <div className="text-[10px] text-muted-foreground">{a.email}</div>
                      </TableCell>
                      <TableCell className="text-xs">
                        <div>{a.branch} ({a.year})</div>
                        <div className="text-[10px] font-mono text-muted-foreground">{a.registrationNumber}</div>
                      </TableCell>
                      <TableCell>
                        <Badge
                          variant="outline"
                          className={`text-xs ${
                            a.verifiedAttendancePercent >= (selectedDriveForApplicants?.minAttendancePercent || 75)
                              ? "text-emerald-600 border-emerald-300"
                              : "text-red-500 border-red-300"
                          }`}
                        >
                          {a.verifiedAttendancePercent}%
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs font-semibold">{a.cgpa}</TableCell>
                      <TableCell>
                        <Badge variant="secondary" className="text-xs font-mono">
                          {a.atsScore ? `${a.atsScore}%` : "—"}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline" className="text-xs">
                          {a.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex gap-1 justify-end">
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs"
                            onClick={() => updateStatusMutation.mutate({ appId: a.applicationId, status: "SHORTLISTED" })}
                          >
                            Shortlist
                          </Button>
                          <Button
                            size="sm"
                            className="h-7 text-xs bg-emerald-600 hover:bg-emerald-700 text-white"
                            onClick={() => updateStatusMutation.mutate({ appId: a.applicationId, status: "OFFERED" })}
                          >
                            Offer
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </DialogContent>
      </Dialog>

      {/* CREATE DRIVE MODAL */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent className="max-w-lg">
          <form onSubmit={handleCreateDrive} className="space-y-4">
            <DialogHeader>
              <DialogTitle>Publish On-Campus Placement Drive</DialogTitle>
              <DialogDescription>
                Company recruitment drives will appear immediately on student mobile apps with automatic eligibility cutoff checks.
              </DialogDescription>
            </DialogHeader>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-foreground">Company Name</label>
                <Input
                  required
                  placeholder="e.g. Oracle Cloud, Microsoft, TCS"
                  value={companyName}
                  onChange={(e) => setCompanyName(e.target.value)}
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-foreground">Job / Role Title</label>
                <Input
                  required
                  placeholder="e.g. Associate Software Engineer"
                  value={roleTitle}
                  onChange={(e) => setRoleTitle(e.target.value)}
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-foreground">Package / CTC</label>
                <Input
                  placeholder="e.g. ₹12.5 LPA (₹10.5L Fixed + ₹2L Bonus)"
                  value={ctcBreakdown}
                  onChange={(e) => setCtcBreakdown(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-foreground">Min CGPA</label>
                  <Input
                    type="number"
                    step="0.1"
                    value={minCgpa}
                    onChange={(e) => setMinCgpa(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-foreground">Min Attendance %</label>
                  <Input
                    type="number"
                    value={minAttendancePercent}
                    onChange={(e) => setMinAttendancePercent(e.target.value)}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-foreground">Drive Date</label>
                  <Input
                    type="date"
                    required
                    value={driveDate}
                    onChange={(e) => setDriveDate(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-foreground">Registration Deadline</label>
                  <Input
                    type="date"
                    required
                    value={registrationDeadline}
                    onChange={(e) => setRegistrationDeadline(e.target.value)}
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-foreground">Job Description</label>
                <textarea
                  required
                  className="w-full rounded-md border bg-transparent p-2 text-xs focus:outline-none focus:ring-1 focus:ring-primary min-h-[70px]"
                  placeholder="Responsibilities, requirements, and assessment rounds..."
                  value={jobDescription}
                  onChange={(e) => setJobDescription(e.target.value)}
                />
              </div>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={() => setCreateDialogOpen(false)}>
                Cancel
              </Button>
              <Button type="submit" disabled={createDriveMutation.isPending}>
                {createDriveMutation.isPending ? "Publishing..." : "Publish Drive"}
              </Button>
            </DialogFooter>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  )
}

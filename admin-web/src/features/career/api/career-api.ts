import { apiClient } from "@/services/api/api-client"

export interface PlacementDrive {
  id: string
  companyName: string
  companyLogoUrl?: string
  roleTitle: string
  jobDescription: string
  location: string
  ctcBreakdown?: string
  stipendAmount?: string
  targetBatches: string[]
  eligibleBranches: string[]
  minCgpa: number
  maxActiveBacklogs: number
  minAttendancePercent: number
  driveDate: string
  registrationDeadline: string
  venue: string
  selectionProcess?: string
  status: string
  createdAt: string
}

export interface DriveApplicant {
  applicationId: string
  status: string
  appliedAt: string
  studentId: string
  studentName: string
  registrationNumber: string
  email: string
  phone?: string
  branch: string
  year: string
  verifiedAttendancePercent: number
  cgpa: number
  activeBacklogs: number
  atsScore: number
  resumeUrl?: string
  githubUrl?: string
  linkedinUrl?: string
}

export interface OpportunityListing {
  id: string
  sourceType: string
  title: string
  companyName: string
  companyLogoUrl?: string
  location: string
  workMode: string
  employmentType: string
  experienceLevel: string
  skills: string[]
  salaryRange?: string
  description: string
  applyUrl: string
  status: string
  createdAt: string
}

export interface CareerAnalytics {
  totalDrivesHosted: number
  totalApplicationsSubmitted: number
  totalOffersExtended: number
  overallPlacementPercent: number
  highestPackage: string
  averagePackage: string
  topRecruiters: string[]
  branchBreakdown: Record<string, {
    totalStudents: number
    placed: number
    placedPercent: number
    avgCtc: string
  }>
}

export const careerApi = {
  getDrives: async (): Promise<PlacementDrive[]> => {
    try {
      const res = await apiClient.get<{ drives: PlacementDrive[] }>("/career/drives")
      return res.drives || []
    } catch {
      return []
    }
  },

  createDrive: async (payload: Partial<PlacementDrive>): Promise<PlacementDrive> => {
    const res = await apiClient.post<{ drive: PlacementDrive }>("/admin/career/drives", payload)
    return res.drive
  },

  getDriveApplicants: async (driveId: string): Promise<DriveApplicant[]> => {
    try {
      const res = await apiClient.get<{ applicants: DriveApplicant[] }>(`/admin/career/drives/${driveId}/applicants`)
      return res.applicants || []
    } catch {
      return []
    }
  },

  updateApplicantStatus: async (applicationId: string, status: string, adminNotes?: string): Promise<void> => {
    await apiClient.patch(`/admin/career/applications/${applicationId}/status`, { status, adminNotes })
  },

  getOpportunities: async (): Promise<OpportunityListing[]> => {
    try {
      const res = await apiClient.get<{ opportunities: OpportunityListing[] }>("/career/opportunities")
      return res.opportunities || []
    } catch {
      return []
    }
  },

  syncExternal: async (): Promise<{ message: string; stats: Record<string, unknown> }> => {
    return apiClient.post("/admin/career/sync", {})
  },

  getAnalytics: async (): Promise<CareerAnalytics> => {
    try {
      return await apiClient.get<CareerAnalytics>("/admin/career/analytics")
    } catch {
      return {
        totalDrivesHosted: 0,
        totalApplicationsSubmitted: 0,
        totalOffersExtended: 0,
        overallPlacementPercent: 0,
        highestPackage: "0 LPA",
        averagePackage: "0 LPA",
        topRecruiters: [],
        branchBreakdown: {},
      }
    }
  },
}

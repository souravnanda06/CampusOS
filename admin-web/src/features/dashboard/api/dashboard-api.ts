import { apiClient } from "@/services/api/api-client"

export interface AdminDashboardSummary {
  totalComplaints: number
  pendingComplaints: number
  assignedComplaints: number
  inProgressComplaints: number
  resolvedComplaints: number
  closedComplaints: number
  reopenedComplaints: number
  rejectedComplaints: number
  ageingComplaints: number
  averageResolutionHours: number
  pendingStudentApprovals?: number
}

export interface AgeingComplaint {
  id: string
  complaintId: string
  title: string
  category: string
  priority: string
  status: string
  createdAt: string
  ageHours: number
  assignedTo: string | null
  assignedToName: string | null
  thresholdHours: number
}

export interface ComplaintCategoryStat {
  category: string
  count: number
}

export interface StaffWorkload {
  staffId: string
  staffName: string
  staffRole: string
  assignedCount: number
  inProgressCount: number
  resolvedCount: number
  totalActive: number
}

export interface HostelKpis {
  totalResidents: number
  totalAssets: number
  damagedAssets: number
  pendingRequests: number
  occupancyRate: number
}

export interface FeeKpis {
  totalBilled: number
  totalCollected: number
  totalOutstanding: number
  overdueAmount: number
  overdueCount: number
  totalRecords: number
}

export interface VisitorKpis {
  totalVisitorRequests: number
  pendingApprovals: number
  approvedPasses: number
  insideCampusNow: number
  completedVisitsToday: number
}

export interface WardenSummaryKpis {
  pendingRequests: number
  pendingVisitors: number
  approvedToday: number
  activeGatePasses: number
}

export const dashboardApi = {
  getSummary: () => apiClient.get<AdminDashboardSummary>("/admin/dashboard/summary"),
  getAgeingComplaints: () => apiClient.get<AgeingComplaint[]>("/admin/complaints/ageing"),
  getCategories: () => apiClient.get<ComplaintCategoryStat[]>("/admin/complaints/categories"),
  getWorkload: () => apiClient.get<StaffWorkload[]>("/admin/complaints/workload"),
  getHostelKpis: () => apiClient.get<HostelKpis>("/hostel/admin/kpis"),
  getFeeKpis: () => apiClient.get<FeeKpis>("/fees/kpis"),
  getVisitorKpis: () => apiClient.get<VisitorKpis>("/visitors/admin/kpis"),
  getWardenSummary: () => apiClient.get<WardenSummaryKpis>("/warden/summary"),
  getActiveSessions: () => apiClient.get<Array<{ id: string }>>("/sessions/active"),
}

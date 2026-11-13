import { apiClient } from "@/services/api/api-client"
import { authService } from "@/services/auth/auth-service"

export interface AdminComplaint {
  id: string
  title: string
  description: string
  category: string
  priority: "LOW" | "MEDIUM" | "HIGH" | "URGENT"
  status: "PENDING" | "ASSIGNED" | "IN_PROGRESS" | "RESOLVED" | "CLOSED" | "REOPENED" | "REJECTED"
  location: string
  studentId: string
  assignedTo: string | null
  assignedToName?: string | null
  createdAt: string
  updatedAt: string
  resolvedAt?: string | null
  ageHours?: number
  isAgeing?: boolean
  recurrenceId?: string | null
  studentName?: string
  closureOtp?: string | null
  hasClosureOtp?: boolean
  otpVerifiedAt?: string | null
  escalationLevel?: number
  escalatedAt?: string | null
  vendorPenaltyFlag?: boolean
  vendorPenaltyAmount?: number
  studentRating?: number | null
  studentFeedback?: string | null
}

export interface ComplaintDetailData {
  complaint: AdminComplaint
  student: {
    id: string
    name: string
    email: string
    registrationNumber?: string
    branch?: string
    year?: string | number
    course?: string
  } | null
  assignedStaff: {
    id: string
    name: string
    email: string
    role: string
  } | null
  statusHistory: {
    id: string
    complaintId: string
    changedBy: string
    oldStatus: string
    newStatus: string
    comment: string
    timestamp: string
    actorName?: string
    actorRole?: string
  }[]
  auditHistory: {
    id: string
    entityType: string
    entityId: string
    actorId: string
    action: string
    remarks: string
    timestamp: string
    actorName?: string
    actorRole?: string
  }[]
}

export interface RecurringCluster {
  recurrenceId: string
  category: string
  location: string
  complaintCount: number
  highestPriority: string
  recurrenceStatus: "ACTIVE" | "RESOLVED"
  escalationLevel?: "NORMAL" | "ELEVATED" | "HIGH" | string
  windowDays?: number
  latestComplaintAt: string
  averageResolutionHours: number
}

export interface RecurringClusterDetail {
  recurrence: RecurringCluster
  complaints: AdminComplaint[]
}

export interface SlingshotDashboardData {
  totalActive: number
  tier1Normal: number
  tier2WardenAlert: number
  tier3DeanSlingshot: number
  vendorPenaltiesTriggered: number
  totalVendorPenaltyAmount: number
  slingshotTickets: (AdminComplaint & { ageHours: number })[]
}

export const complaintsApi = {
  getComplaints: (params?: {
    status?: string
    priority?: string
    category?: string
    assignedTo?: string
    ageing?: boolean | string
    search?: string
    order?: string
  }) => apiClient.get<AdminComplaint[]>("/admin/complaints", { params }),

  getComplaintDetail: (id: string) =>
    apiClient.get<ComplaintDetailData>(`/admin/complaints/${id}`),

  getRecurringClusters: () =>
    apiClient.get<RecurringCluster[]>("/admin/complaints/recurring"),

  getRecurringClusterDetail: (recurrenceId: string) =>
    apiClient.get<RecurringClusterDetail>(`/admin/complaints/recurring/${recurrenceId}`),

  assignComplaint: (id: string, assignedTo: string, remarks?: string) =>
    apiClient.post<{ message: string; complaint: AdminComplaint }>(`/complaints/${id}/assign`, {
      actorId: authService.getCurrentUser()?.id,
      assignedTo,
      remarks,
    }),

  actionComplaint: (id: string, action: string, remarks?: string, assignedTo?: string, otp?: string) =>
    apiClient.post<{ message: string; complaint: AdminComplaint }>(`/complaints/${id}/action`, {
      actorId: authService.getCurrentUser()?.id,
      action,
      remarks,
      assignedTo,
      otp,
    }),

  verifyResolveComplaint: (id: string, otp: string, remarks: string) =>
    apiClient.post<{ message: string; complaint: AdminComplaint }>(`/complaints/${id}/verify-resolve`, {
      actorId: authService.getCurrentUser()?.id,
      otp,
      remarks,
    }),

  getSlingshotDashboard: () =>
    apiClient.get<SlingshotDashboardData>("/complaints/slingshot/dashboard"),

  evaluateSlingshot: () =>
    apiClient.post<{
      message: string
      evaluatedCount: number
      escalatedToTier2Count: number
      escalatedToTier3Count: number
      tier2ComplaintIds: string[]
      tier3ComplaintIds: string[]
    }>("/complaints/slingshot/evaluate"),
}

import { apiClient } from "@/services/api/api-client"
import { authService } from "@/services/auth/auth-service"

export interface LeaveRequestItem {
  id: string
  studentId: string
  leaveType: string
  startDate: string
  endDate: string
  reason: string
  destination?: string | null
  parentConsent: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED"
  reviewedBy?: string | null
  reviewRemarks?: string | null
  createdAt: string
  updatedAt?: string
  studentName?: string
  registrationNumber?: string
  course?: string
  branch?: string
  year?: string | number
  previousRequestsCount?: number
  gatePass?: {
    id: string
    status: string
    destination: string
    expectedExitTime: string
    expectedReturnTime: string
  } | null
}

export interface WardenSummaryData {
  pendingRequests: number
  pendingVisitors: number
  approvedToday: number
  activeGatePasses: number
  recentActivityCount: number
  pendingPreview: LeaveRequestItem[]
}

export const leavesApi = {
  getSummary: () => apiClient.get<WardenSummaryData>("/warden/summary"),

  getLeaveRequests: (params?: { status?: string; search?: string }) =>
    apiClient.get<LeaveRequestItem[]>("/warden/leave-requests", {
      params: {
        status: params?.status && params.status !== "ALL" ? params.status : undefined,
        search: params?.search || undefined,
      },
    }),

  getLeaveDetail: (id: string) =>
    apiClient.get<LeaveRequestItem>(`/warden/leave-requests/${id}`),

  actionLeaveRequest: (
    id: string,
    action: "APPROVE" | "REJECT" | "ASK_STUDENT",
    remarks?: string
  ) =>
    apiClient.post<{
      message: string
      request: LeaveRequestItem
      gatePass?: Record<string, unknown>
    }>(`/warden/leave-requests/${id}/action`, {
      reviewerId: authService.getCurrentUser()?.id,
      action,
      remarks,
    }),
}

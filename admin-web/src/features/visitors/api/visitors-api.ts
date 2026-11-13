import { apiClient, ApiError } from "@/services/api/api-client"

export interface VisitorRequestItem {
  id: string
  studentId: string
  visitorName: string
  visitorPhone: string
  relation: string
  purpose: string
  visitDate: string
  expectedEntryTime: string
  expectedExitTime: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "CHECKED_IN" | "CHECKED_OUT" | "EXPIRED" | string
  passCode?: string | null
  enteredAt?: string | null
  exitedAt?: string | null
  wardenRemarks?: string | null
  securityRemarks?: string | null
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
  createdAt: string
}

export interface VisitorKpisData {
  totalVisitorRequests: number
  pendingApprovals: number
  approvedPasses: number
  insideCampusNow: number
  completedVisitsToday: number
}

export const visitorsApi = {
  getKpis: () => apiClient.get<VisitorKpisData>("/visitors/admin/kpis"),

  getAllRequests: async (status?: string) => {
    try {
      return await apiClient.get<VisitorRequestItem[]>("/visitors/admin/all", {
        params: status && status !== "ALL" ? { status } : undefined,
      })
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        const pending = await apiClient.get<VisitorRequestItem[]>("/visitors/warden/pending")
        if (status && status !== "ALL") {
          return pending.filter((v) => v.status === status)
        }
        return pending
      }
      throw err
    }
  },

  getPendingRequests: () =>
    apiClient.get<VisitorRequestItem[]>("/visitors/warden/pending"),

  actionRequest: (id: string, action: "APPROVE" | "REJECT", remarks?: string) =>
    apiClient.post<{ message: string; request: VisitorRequestItem }>(
      `/visitors/warden/requests/${id}/action`,
      { action, remarks }
    ),

  checkInVisitor: (passCode: string, remarks?: string) =>
    apiClient.post<{ message: string; pass: VisitorRequestItem }>(
      "/visitors/security/check-in",
      { passCode, remarks }
    ),

  checkOutVisitor: (passCode: string, remarks?: string) =>
    apiClient.post<{ message: string; pass: VisitorRequestItem }>(
      "/visitors/security/check-out",
      { passCode, remarks }
    ),
}

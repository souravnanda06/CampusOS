import { apiClient } from "@/services/api/api-client"

export interface VisitorRequestItem {
  id: string
  student_id: string
  visitor_name: string
  visitor_phone: string
  relation: string
  purpose: string
  visit_date: string
  expected_entry_time: string
  expected_exit_time: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "CHECKED_IN" | "CHECKED_OUT" | "EXPIRED"
  pass_code?: string
  entered_at?: string | null
  exited_at?: string | null
  warden_remarks?: string
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
  created_at: string
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

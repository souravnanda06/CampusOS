import { apiClient } from "@/services/api/api-client"

export interface GateSecuritySummary {
  gateStatus: string
  currentTime: string
  activeShift: string
  passesAwaitingVerification: number
  studentsOutside: number
  recentlyExited: number
  recentlyReturned: number
  failedAttempts: number
  offlineSyncPendingCount: number
}

export interface SecurityGatePass {
  id: string
  studentId: string
  destination: string
  reason: string
  expectedExitTime: string
  expectedReturnTime: string
  actualExitTime?: string | null
  actualReturnTime?: string | null
  status: "ISSUED" | "EXITED" | "RETURNED" | "EXPIRED" | "CANCELLED" | string
  verificationMode?: string | null
  student: {
    id: string
    name: string
    registrationNumber: string
    course: string
    branch: string
    year: string | number
  }
}

export interface GateActivityItem {
  id: string
  passId: string
  operation: "EXIT" | "RETURN" | "VERIFY" | string
  result: "SUCCESS" | "FAILED" | "DUPLICATE" | string
  verificationMode: string
  timestamp: string
  remarks: string
  student: {
    id: string | null
    name: string
    registrationNumber: string
  }
  securityStaff: {
    id: string | null
    name: string
  }
}

export const securityApi = {
  getSummary: () => apiClient.get<GateSecuritySummary>("/security/gate-pass/summary"),

  getGatePasses: (params?: { status?: string; search?: string }) =>
    apiClient.get<SecurityGatePass[]>("/security/gate-passes", { params }),

  getActivity: (filter: string = "ALL") =>
    apiClient.get<GateActivityItem[]>("/security/gate-pass/activity", {
      params: { filter },
    }),

  recordExit: (id: string, remarks?: string) =>
    apiClient.post<{ message: string; gatePass: SecurityGatePass }>(
      `/security/gate-pass/${id}/exit`,
      { remarks }
    ),

  recordReturn: (id: string, remarks?: string) =>
    apiClient.post<{ message: string; gatePass: SecurityGatePass }>(
      `/security/gate-pass/${id}/return`,
      { remarks }
    ),
}

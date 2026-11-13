import { apiClient } from "@/services/api/api-client"

export type StudentApprovalStatus = "PENDING" | "APPROVED" | "REJECTED"

export interface StudentRecord {
  id: string
  name: string
  email: string
  role: string
  registrationNumber?: string
  course?: string
  branch?: string
  year?: string | number
  deviceId?: string | null
  attendancePercentage?: number
  phone?: string
  parentPhone?: string
  parentName?: string
  approvalStatus?: StudentApprovalStatus
  approvedBy?: string | null
  approvedAt?: string | null
  rejectionReason?: string | null
  photoUrl?: string | null
  createdAt?: string | null
}

export interface StaffRecord {
  id: string
  name: string
  email: string
  role: string
  branch?: string
  course?: string
}

export interface CreateUserPayload {
  name: string
  email: string
  password: string
  role: string
  registrationNumber?: string
  course?: string
  branch?: string
  year?: string
}

export interface UpdateUserPayload {
  name?: string
  role?: string
  branch?: string
  course?: string
  year?: string
  registrationNumber?: string
  resetDeviceId?: boolean
  password?: string
}

export interface StudentAnalytics {
  overallPercentage: number
  totalClasses: number
  attendedClasses: number
  subjects: {
    subject: string
    percentage: number
    trend: string
  }[]
}

export interface AttendanceItem {
  id: string
  sessionId: string
  studentName: string
  checkInTime: string
  status: string
  verificationMode?: string
}

export interface StudentPassportKey {
  keyId: string
  userId: string
  publicKey: string
  keyType: string
  status: string
  certificate?: {
    certificateId?: string
    id?: string
    status: string
    validFrom: string
    validTo: string
  } | null
}

export const studentsApi = {
  getStudentsWithStats: async (params?: { course?: string; branch?: string; year?: string }): Promise<StudentRecord[]> => {
    try {
      const res = await apiClient.get<StudentRecord[] | { students: StudentRecord[] }>("/students-with-stats", { params })
      if (Array.isArray(res)) return res
      if (res && Array.isArray((res as any).students)) return (res as any).students
      return []
    } catch (err) {
      console.error("Failed to fetch students with stats", err)
      return []
    }
  },

  getAdminStudents: async (params?: { approvalStatus?: string; branch?: string; year?: string; search?: string }): Promise<StudentRecord[]> => {
    try {
      const res = await apiClient.get<StudentRecord[] | { students: StudentRecord[] }>("/admin/students", { params })
      if (Array.isArray(res)) return res
      if (res && Array.isArray((res as any).students)) return (res as any).students
      return []
    } catch (err) {
      console.error("Failed to fetch admin students", err)
      return []
    }
  },

  getPendingStudents: async (): Promise<StudentRecord[]> => {
    try {
      const res = await apiClient.get<StudentRecord[] | { students: StudentRecord[] }>("/admin/students/pending")
      if (Array.isArray(res)) return res
      if (res && Array.isArray((res as any).students)) return (res as any).students
      return []
    } catch (err) {
      console.error("Failed to fetch pending student approvals", err)
      return []
    }
  },

  approveStudent: (studentId: string) =>
    apiClient.post<{ message: string; student: StudentRecord }>(`/admin/students/${studentId}/approve`),

  bulkApproveStudents: (studentIds: string[]) =>
    apiClient.post<{ message: string; approvedCount: number; approvedIds: string[] }>(
      "/admin/students/bulk-approve",
      { studentIds }
    ),

  rejectStudent: (studentId: string, reason?: string) =>
    apiClient.post<{ message: string; student: StudentRecord }>(`/admin/students/${studentId}/reject`, { reason }),

  getStaff: () => apiClient.get<StaffRecord[]>("/admin/staff"),

  createUser: (payload: CreateUserPayload) =>
    apiClient.post<{ message: string; user: StaffRecord }>("/admin/users", payload),

  updateUser: (userId: string, payload: UpdateUserPayload) =>
    apiClient.patch<{ message: string; user: StaffRecord }>(`/admin/users/${userId}`, payload),

  deleteUser: (userId: string) =>
    apiClient.delete<{ message: string }>(`/admin/users/${userId}`),

  getStudentAnalytics: (studentId: string) =>
    apiClient.get<StudentAnalytics>(`/analytics/dashboard/${studentId}`).catch(() => null),

  getStudentAttendance: (studentId: string) =>
    apiClient.get<AttendanceItem[]>(`/attendance/student/${studentId}`).catch(() => []),

  getStudentComplaints: (studentId: string) =>
    apiClient.get<unknown[]>(`/complaints/student/${studentId}`).catch(() => []),

  getStudentPassport: (studentId: string) =>
    apiClient.get<StudentPassportKey>(`/passport/keys/${studentId}`).catch(() => null),

  getStudentGatePasses: (studentId: string) =>
    apiClient.get<unknown[]>(`/requests/gate-pass/${studentId}`).catch(() => []),

  getStudentLeaves: (studentId: string) =>
    apiClient.get<unknown[]>(`/requests/leave/${studentId}`).catch(() => []),

  resetDeviceId: (studentId: string) =>
    apiClient.post<{ message: string }>("/teacher/reset-device-id", { studentId }),
}

import { apiClient } from "@/services/api/api-client"

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
}

export interface StaffRecord {
  id: string
  name: string
  email: string
  role: string
  branch?: string
  course?: string
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
    certificateId: string
    status: string
    validFrom: string
    validTo: string
  } | null
}

export const studentsApi = {
  getStudentsWithStats: (params?: { course?: string; branch?: string; year?: string }) =>
    apiClient.get<StudentRecord[]>("/students-with-stats", { params }),

  getStaff: () => apiClient.get<StaffRecord[]>("/admin/staff"),

  getStudentAnalytics: (studentId: string) =>
    apiClient.get<StudentAnalytics>(`/analytics/dashboard/${studentId}`).catch(() => null),

  getStudentAttendance: (studentId: string) =>
    apiClient.get<AttendanceItem[]>(`/attendance/student/${studentId}`).catch(() => []),

  getStudentComplaints: (studentId: string) =>
    apiClient.get<any[]>(`/complaints/student/${studentId}`).catch(() => []),

  getStudentPassport: (studentId: string) =>
    apiClient.get<StudentPassportKey>(`/passport/keys/${studentId}`).catch(() => null),

  getStudentGatePasses: (studentId: string) =>
    apiClient.get<any[]>(`/requests/gate-pass/${studentId}`).catch(() => []),

  getStudentLeaves: (studentId: string) =>
    apiClient.get<any[]>(`/requests/leave/${studentId}`).catch(() => []),

  resetDeviceId: (studentId: string) =>
    apiClient.post<{ message: string }>("/teacher/reset-device-id", { studentId }),
}

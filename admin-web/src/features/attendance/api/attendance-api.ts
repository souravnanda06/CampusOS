import { apiClient } from "@/services/api/api-client"

export interface LectureSession {
  id: string
  name: string
  subject: string
  instructorName?: string
  instructor_name?: string
  course?: string
  branch?: string
  year?: string | number
  startTime?: string
  start_time?: string
  endTime?: string
  end_time?: string
  location?: string
  isActive?: boolean
  is_active?: boolean
  attendanceCount?: number
  attendance_count?: number
  sessionNonce?: string
  session_nonce?: string
  teacherKeyId?: string
  teacher_key_id?: string
}

export interface SessionAttendee {
  id: string
  sessionId: string
  studentName: string
  userId?: string
  checkInTime: string
  status: string
  verificationMode?: string
  couponEarned?: boolean
}

export const attendanceApi = {
  getActiveSessions: () => apiClient.get<LectureSession[]>("/sessions/active").catch(() => []),
  getSessionHistory: (instructorName?: string) =>
    apiClient
      .get<LectureSession[]>("/sessions/history", {
        params: instructorName ? { instructorName } : undefined,
      })
      .catch(() => []),
  getSessionAttendance: (sessionId: string) =>
    apiClient.get<SessionAttendee[]>(`/attendance/session/${sessionId}`).catch(() => []),
  stopSession: (sessionId: string) =>
    apiClient.post<{ message: string }>(`/sessions/stop/${sessionId}`),
}

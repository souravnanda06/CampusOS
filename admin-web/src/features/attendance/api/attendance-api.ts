import { apiClient } from "@/services/api/api-client"

export interface LectureSession {
  id: string
  name: string
  subject: string
  instructor_name: string
  course: string
  branch: string
  year: string | number
  start_time: string
  end_time?: string
  location?: string
  is_active: boolean
  attendance_count: number
  session_nonce?: string
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
  getActiveSessions: () => apiClient.get<LectureSession[]>("/sessions/active"),
  getSessionHistory: (instructorName?: string) =>
    apiClient.get<LectureSession[]>("/sessions/history", {
      params: instructorName ? { instructorName } : undefined,
    }).catch(() => []),
  getSessionAttendance: (sessionId: string) =>
    apiClient.get<SessionAttendee[]>(`/attendance/session/${sessionId}`),
  stopSession: (sessionId: string) =>
    apiClient.post<{ message: string }>(`/sessions/stop/${sessionId}`),
}

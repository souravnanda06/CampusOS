import { apiClient } from "@/services/api/api-client"

export interface ClassUpdateItem {
  id: string
  course_code: string
  course_name: string
  update_type: "CANCELLED" | "RESCHEDULED" | "ROOM_CHANGE" | "TIME_CHANGE" | "ANNOUNCEMENT"
  original_date: string
  original_time?: string
  original_room?: string
  new_date?: string
  new_time?: string
  new_room?: string
  message: string
  affected_branch?: string
  affected_year?: number
  affected_section?: string
  teacher_id: string
  teacherName?: string
  created_at: string
}

export interface TodayUpdatesSummary {
  todayTotal: number
  cancellationsCount: number
  rescheduledCount: number
  updates: ClassUpdateItem[]
}

export interface CreateClassUpdatePayload {
  courseCode: string
  courseName: string
  updateType: "CANCELLED" | "RESCHEDULED" | "ROOM_CHANGE" | "TIME_CHANGE" | "ANNOUNCEMENT"
  originalDate?: string
  originalTime?: string
  originalRoom?: string
  newDate?: string
  newTime?: string
  newRoom?: string
  message: string
  affectedBranch?: string
  affectedYear?: number
  affectedSection?: string
}

export const academicApi = {
  getAllUpdates: () => apiClient.get<ClassUpdateItem[]>("/academic-updates/all"),
  getTodaySummary: () => apiClient.get<TodayUpdatesSummary>("/academic-updates/today-summary"),
  createUpdate: (payload: CreateClassUpdatePayload) =>
    apiClient.post<{ message: string; update: ClassUpdateItem; affectedStudentsCount: number }>(
      "/academic-updates",
      payload
    ),
}

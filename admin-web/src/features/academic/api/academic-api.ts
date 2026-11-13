import { apiClient } from "@/services/api/api-client"

export interface ClassUpdateItem {
  id: string
  teacherId: string
  teacherName?: string
  courseCode: string
  courseName: string
  updateType: "CANCELLED" | "RESCHEDULED" | "ROOM_CHANGE" | "TIME_CHANGE" | "ANNOUNCEMENT" | string
  originalDate?: string | null
  originalTime?: string | null
  originalRoom?: string | null
  newDate?: string | null
  newTime?: string | null
  newRoom?: string | null
  message: string
  affectedBranch?: string | null
  affectedYear?: number | null
  affectedSection?: string | null
  status: "ACTIVE" | "CANCELLED" | "ARCHIVED" | string
  createdAt: string
  updatedAt?: string | null
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
  cancelUpdate: (id: string) =>
    apiClient.post<{ message: string; update: ClassUpdateItem }>(
      `/academic-updates/${id}/cancel`,
      {}
    ),
}

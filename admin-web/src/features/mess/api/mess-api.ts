import { apiClient } from "@/services/api/api-client"

export type MealType = "BREAKFAST" | "LUNCH" | "SNACKS" | "DINNER"

export interface MessMealItem {
  id?: string
  mealType: MealType
  title: string
  description?: string
  items: string[]
  availability: "AVAILABLE" | "LIMITED" | "SPECIAL" | "UNAVAILABLE"
  displayOrder: number
}

export interface MessMenuRecord {
  id: string
  menuDate: string
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED"
  createdBy?: string
  updatedBy?: string
  createdAt: string
  updatedAt: string
  meals: MessMealItem[]
}

export interface MessFeedbackSummary {
  totalRatings: number
  feedbackCount?: number
  averageRating: number
  totalComments: number
  ratingDistribution: Record<string, number>
  mealBreakdown: Record<string, { count: number; averageRating: number }>
}

export interface MessTrendPoint {
  date: string
  ratingCount: number
  averageRating: number
  mealBreakdown: Record<string, { count: number; averageRating: number }>
}

export interface MessCategoryStat {
  category: string
  feedbackCount: number
  averageRating: number
  negativeCount: number
  positiveCount: number
  negativePercentage: number
}

export interface MessCategorySignal {
  category: string
  feedbackCount: number
  averageRating: number
  negativeCount: number
  negativePercentage: number
  flagged: boolean
  flagReason?: string | null
}

export interface MessFeedbackComment {
  id: string
  rating: number
  category: string
  comment?: string | null
  mealType?: string | null
  menuDate?: string | null
  createdAt: string
}

export interface MessEntriesToday {
  date: string
  activeMeal: string
  mealTiming?: string | null
  menuStatus?: string | null
  todayMenuId?: string | null
  totalVerifiedToday: number
  counts: Record<string, { total: number; batch: number; qr: number }>
  recentEntries?: Array<{
    id: string
    studentId?: string
    studentName?: string
    mealType: string
    verificationMode: string
    verifiedAt: string
  }>
}

export interface MessEntriesAnalytics {
  totalEntries: number
  batchEntries: number
  qrEntries: number
  todayEntries: number
  mealBreakdown: Record<string, number>
}

export const messApi = {
  getAdminMenus: (status?: string) =>
    apiClient.get<MessMenuRecord[]>("/mess/admin/menus", {
      params: status && status !== "ALL" ? { status } : undefined,
    }),

  getPublishedMenus: () =>
    apiClient.get<MessMenuRecord[]>("/mess/menus"),

  getFeedbackSummary: () =>
    apiClient.get<MessFeedbackSummary>("/mess/admin/feedback/summary"),

  getFeedbackTrends: () =>
    apiClient.get<{ trends: MessTrendPoint[] }>("/mess/admin/feedback/trends"),

  getFeedbackCategories: () =>
    apiClient.get<{ categories: MessCategoryStat[]; signals: MessCategorySignal[] }>(
      "/mess/admin/feedback/categories"
    ),

  getFeedbackComments: (params?: { minRating?: number; maxRating?: number; limit?: number }) =>
    apiClient.get<MessFeedbackComment[]>("/mess/admin/feedback/comments", {
      params,
    }),

  getTodayMealStats: () =>
    apiClient.get<MessEntriesToday>("/mess/entries/today"),

  getEntriesAnalytics: () =>
    apiClient.get<MessEntriesAnalytics>("/mess/entries/analytics"),

  createMenu: (menuDate: string, meals: MessMealItem[], status: "DRAFT" | "PUBLISHED" = "DRAFT") =>
    apiClient.post<MessMenuRecord>("/mess/menus", {
      menuDate,
      status,
      meals: meals.map((m) => ({
        mealType: m.mealType,
        title: m.title,
        description: m.description || "",
        items: m.items,
        availability: m.availability || "AVAILABLE",
        displayOrder: m.displayOrder,
      })),
    }),

  updateMenu: (
    id: string,
    payload: { menuDate?: string; status?: "DRAFT" | "PUBLISHED" | "ARCHIVED"; meals?: MessMealItem[] }
  ) =>
    apiClient.patch<MessMenuRecord>(`/mess/menus/${id}`, {
      ...(payload.menuDate ? { menuDate: payload.menuDate } : {}),
      ...(payload.status ? { status: payload.status } : {}),
      ...(payload.meals
        ? {
            meals: payload.meals.map((m) => ({
              mealType: m.mealType,
              title: m.title,
              description: m.description || "",
              items: m.items,
              availability: m.availability || "AVAILABLE",
              displayOrder: m.displayOrder,
            })),
          }
        : {}),
    }),

  publishMenu: (id: string) =>
    apiClient.post<MessMenuRecord>(`/mess/menus/${id}/publish`, {}),

  archiveMenu: (id: string) =>
    apiClient.post<MessMenuRecord>(`/mess/menus/${id}/archive`, {}),
}

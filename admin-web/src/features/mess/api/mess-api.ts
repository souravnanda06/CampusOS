import { apiClient } from "@/services/api/api-client"

export interface MessMealItem {
  id?: string
  meal_type: "BREAKFAST" | "LUNCH" | "SNACKS" | "DINNER"
  title: string
  description?: string
  items: string[]
  availability: "AVAILABLE" | "LIMITED" | "SPECIAL" | "UNAVAILABLE"
  display_order: number
}

export interface MessMenuRecord {
  id: string
  menu_date: string
  status: "DRAFT" | "PUBLISHED" | "ARCHIVED"
  created_at: string
  updated_at: string
  meals: MessMealItem[]
}

export interface MessFeedbackSummary {
  totalRatings: number
  averageRating: number
  totalComments: number
  ratingDistribution: Record<string, number>
  mealBreakdown: Record<string, { count: number; averageRating: number }>
}

export interface MessEntriesToday {
  date: string
  totalEntries: number
  byMealType: Record<string, number>
}

export const messApi = {
  getAdminMenus: (status?: string) =>
    apiClient.get<MessMenuRecord[]>("/mess/admin/menus", {
      params: status && status !== "ALL" ? { status } : undefined,
    }).catch(() => []),

  getPublishedMenus: () =>
    apiClient.get<MessMenuRecord[]>("/mess/menus").catch(() => []),

  getFeedbackSummary: () =>
    apiClient.get<MessFeedbackSummary>("/mess/admin/feedback/summary").catch(() => ({
      totalRatings: 0,
      averageRating: 0,
      totalComments: 0,
      ratingDistribution: { "1": 0, "2": 0, "3": 0, "4": 0, "5": 0 },
      mealBreakdown: {},
    })),

  getTodayMealStats: () =>
    apiClient.get<MessEntriesToday>("/mess/entries/today").catch(() => ({
      date: new Date().toISOString().split("T")[0],
      totalEntries: 0,
      byMealType: {},
    })),

  createMenu: (menuDate: string, meals: MessMealItem[], status: "DRAFT" | "PUBLISHED" = "DRAFT") =>
    apiClient.post<MessMenuRecord>("/mess/menus", {
      menuDate,
      status,
      meals: meals.map((m) => ({
        meal_type: m.meal_type,
        title: m.title,
        description: m.description || "",
        items: m.items,
        availability: m.availability || "AVAILABLE",
        display_order: m.display_order,
      })),
    }),

  publishMenu: (id: string) =>
    apiClient.post<MessMenuRecord>(`/mess/menus/${id}/publish`),

  archiveMenu: (id: string) =>
    apiClient.post<MessMenuRecord>(`/mess/menus/${id}/archive`),
}

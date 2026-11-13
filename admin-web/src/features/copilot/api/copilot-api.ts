import { apiClient } from "@/services/api/api-client"

export interface CopilotSuggestion {
  label: string
  prompt: string
}

export interface CopilotCardMetricItem {
  label: string
  value: string
}

export interface CopilotCardRow {
  title: string
  subtitle?: string
  badge?: string
}

export interface CopilotCard {
  type: "metrics" | "list" | string
  title: string
  items?: CopilotCardMetricItem[]
  rows?: CopilotCardRow[]
  summary?: string
  sections?: Array<{ heading?: string; body?: string; items?: string[] }>
}

export interface CopilotPendingAction {
  actionId: string
  actionType: string
  title: string
  summary: string
  payload: Record<string, unknown>
  status: "PENDING_CONFIRMATION" | "EXECUTED" | "CANCELLED" | string
}

export interface CopilotChatResponse {
  reply: string
  role: string
  mode: string
  cards: CopilotCard[]
  pendingActions: CopilotPendingAction[]
  toolsUsed: string[]
  suggestedPrompts: CopilotSuggestion[]
}

export interface CopilotConfirmResponse {
  message: string
  status: string
  actionId: string
  actionType?: string
  result?: Record<string, unknown>
}

export const copilotApi = {
  getSuggestions: () =>
    apiClient.get<{ role: string; suggestions: CopilotSuggestion[] }>("/copilot/suggestions"),

  chat: (params: {
    message: string
    history: Array<{ role: "user" | "assistant"; text: string }>
    screenContext?: string
    files?: File[]
  }) => {
    if (params.files && params.files.length > 0) {
      const form = new FormData()
      form.append("message", params.message)
      form.append("language", "en")
      if (params.screenContext) form.append("screenContext", params.screenContext)
      form.append("history", JSON.stringify(params.history.slice(-10)))
      params.files.slice(0, 3).forEach((f) => form.append("files", f))
      return apiClient.post<CopilotChatResponse>("/copilot/chat", form, { timeoutMs: 45000 })
    }
    return apiClient.post<CopilotChatResponse>(
      "/copilot/chat",
      {
        message: params.message,
        history: params.history.slice(-10),
        language: "en",
        screenContext: params.screenContext,
      },
      { timeoutMs: 45000 }
    )
  },

  confirmAction: (actionId: string) =>
    apiClient.post<CopilotConfirmResponse>("/copilot/confirm", { actionId }),
}

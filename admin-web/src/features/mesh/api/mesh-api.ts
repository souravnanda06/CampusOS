import { apiClient } from "@/services/api/api-client"
import { authService } from "@/services/auth/auth-service"

export interface MeshChannelItem {
  channelId: string
  name: string
  description: string
  isDirectMessage: boolean
  participants: string[]
  status?: string
  isRestricted?: boolean
  restrictedReason?: string
  restrictedBy?: string
  restrictedAt?: number
}

export interface MeshMessageItem {
  messageId: string
  channelId: string
  senderDeviceId: string
  senderUserId?: string | null
  senderDisplayName: string
  senderRole: string
  text: string
  isEncrypted?: boolean
  createdAt: number
  hopCount?: number
  ttl?: number
  signatureVerified?: boolean
  verificationState?: string
  moderationStatus?: string
  moderationSeverity?: string
}

export interface MeshReportedUserSummary {
  userId?: string | null
  name: string
  email?: string | null
  role: string
  registrationNumber?: string | null
  keyStatus: "ACTIVE" | "REVOKED" | "UNREGISTERED" | string
  accountStatus: "ACTIVE" | "RESTRICTED" | "REVOKED" | string
  restrictionReason?: string | null
  totalFlags: number
}

export interface MeshFlaggedAccountItem extends MeshReportedUserSummary {
  openFlags: number
  criticalFlags: number
  lastFlaggedAt: number
  reasons: string[]
  categories: string[]
  latestMessage?: string
}

export interface MeshModerationFlagItem {
  flagId: string
  messageId: string
  channelId: string
  reportedUserId?: string | null
  reportedDeviceId?: string | null
  reporterUserId: string
  reporterName?: string
  reportedUser?: MeshReportedUserSummary
  source: string
  category: string
  severity: string
  matchedPatterns: string[]
  messageSnapshot: string
  signatureVerified: boolean
  status: string
  resolutionNotes?: string | null
  createdAt: number
  resolvedAt?: number | null
}

export type MeshFlagAction =
  | "DISMISS"
  | "HIDE_MESSAGE"
  | "ESCALATE"
  | "RESTRICT_ACCOUNT"
  | "REVOKE_KEY"
  | "RESTORE_ACCOUNT"
  | "RESTRICT_CHANNEL"
  | "DISMANTLE_CHANNEL"

export type MeshAccountAction = "RESTRICT" | "REVOKE_KEY" | "RESTORE"

export const meshApi = {
  getHealth: () =>
    apiClient.get<{ configured: boolean; connected: boolean; storage: string; messageCount: number }>(
      "/mesh-chat/health"
    ),

  getChannels: () =>
    apiClient.get<{ channels: MeshChannelItem[] }>("/mesh-chat/channels").then((r) => r.channels || []),

  createChannel: (name: string, description?: string) =>
    apiClient.post<{ channel: MeshChannelItem }>("/mesh-chat/channels", { name, description }),

  restrictChannel: (channelId: string, action: "RESTRICT" | "DISMANTLE" | "RESTORE", reason?: string) =>
    apiClient.post<{ channel: MeshChannelItem }>(
      `/mesh-chat/admin/channels/${encodeURIComponent(channelId)}/restrict`,
      { action, reason }
    ),

  getChannelMessages: (channelId: string, limit = 100) =>
    apiClient
      .get<{ channelId: string; messages: MeshMessageItem[]; count: number }>(
        `/mesh-chat/channels/${encodeURIComponent(channelId)}/messages`,
        { params: { limit } }
      )
      .then((r) => r.messages || []),

  broadcastMessage: (channelId: string, text: string) => {
    const user = authService.getCurrentUser()
    const messageId = `adm_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    return apiClient.post<{ syncedIds: string[]; rejected: Array<{ messageId: string; reason: string }> }>(
      "/mesh-chat/sync",
      {
        messages: [
          {
            messageId,
            channelId,
            text,
            senderUserId: user?.id,
            senderDeviceId: user?.id || "admin_web_console",
            senderDisplayName: user?.name || "Dean Admin",
            senderRole: user?.role || "admin",
            createdAt: Date.now(),
            hopCount: 0,
            ttl: 7,
            verificationState: "TRUSTED",
          },
        ],
      }
    )
  },

  getModerationFlags: (status?: string) =>
    apiClient
      .get<{ flags: MeshModerationFlagItem[]; count: number }>("/mesh-chat/admin/flags", {
        params: status && status !== "ALL" ? { status } : undefined,
      })
      .then((r) => r.flags || []),

  resolveModerationFlag: (flagId: string, action: MeshFlagAction, notes?: string) =>
    apiClient.patch<{ flag: MeshModerationFlagItem }>(
      `/mesh-chat/admin/flags/${encodeURIComponent(flagId)}`,
      { action, notes }
    ),

  getFlaggedAccounts: () =>
    apiClient
      .get<{ accounts: MeshFlaggedAccountItem[]; count: number }>("/mesh-chat/admin/accounts")
      .then((r) => r.accounts || [])
      .catch(() => []),

  controlFlaggedAccount: (userId: string, action: MeshAccountAction, reason?: string) =>
    apiClient.patch<{ account: MeshReportedUserSummary }>(
      `/mesh-chat/admin/accounts/${encodeURIComponent(userId)}`,
      { action, reason }
    ),

  moderateMessage: (
    messageId: string,
    payload: { category: string; severity: string; reason: string; hideMessage: boolean }
  ) =>
    apiClient.post<{ flag: MeshModerationFlagItem; message: MeshMessageItem }>(
      `/mesh-chat/admin/messages/${encodeURIComponent(messageId)}/moderate`,
      payload
    ),
}

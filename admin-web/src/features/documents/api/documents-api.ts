import { apiClient } from "@/services/api/api-client"

export interface DocumentRequestItem {
  id: string
  studentId: string
  documentType: string
  documentTypeName?: string
  purpose: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "ISSUED" | string
  adminNotes?: string | null
  documentNumber?: string | null
  fileUrl?: string | null
  issuedAt?: string | null
  expiresAt?: string | null
  storedInWallet?: boolean
  walletAddedAt?: string | null
  createdAt: string
  updatedAt?: string | null
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
  email?: string
}

export interface DocumentKpisData {
  pendingRequests: number
  approvedAwaitingIssue: number
  totalIssued: number
  totalRejected: number
}

export interface DocumentTypeItem {
  type: string
  name: string
}

export const documentsApi = {
  getKpis: () => apiClient.get<DocumentKpisData>("/documents/kpis"),

  getTypes: () => apiClient.get<DocumentTypeItem[]>("/documents/types"),

  getAllRequests: (status?: string) =>
    apiClient.get<DocumentRequestItem[]>("/documents/requests/all", {
      params: status && status !== "ALL" ? { status } : undefined,
    }),

  getPendingRequests: () =>
    apiClient.get<DocumentRequestItem[]>("/documents/requests/pending"),

  actionRequest: (id: string, action: "APPROVE" | "REJECT" | "ISSUE", adminNotes?: string) =>
    apiClient.post<{ message: string; document: DocumentRequestItem }>(
      `/documents/requests/${id}/action`,
      { action, adminNotes }
    ),
}

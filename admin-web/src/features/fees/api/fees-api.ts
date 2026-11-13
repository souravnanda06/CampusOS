import { apiClient } from "@/services/api/api-client"

export interface FeeRecordItem {
  id: string
  studentId: string
  title: string
  category: "TUITION" | "HOSTEL" | "EXAM" | "LIBRARY" | "OTHER" | string
  amount: number
  amountPaid: number
  balanceDue: number
  dueDate: string
  paidAt?: string | null
  status: "DUE" | "PARTIALLY_PAID" | "PAID" | "OVERDUE" | "WAIVED" | string
  receiptNumber?: string | null
  academicYear: string
  semester: number
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
}

export interface FeeKpisData {
  totalBilled: number
  totalCollected: number
  totalOutstanding: number
  overdueAmount: number
  overdueCount: number
  totalRecords: number
}

export interface CreateFeePayload {
  studentId: string
  title: string
  category: string
  amount: number
  dueDate: string
  academicYear?: string
  semester?: number
}

export interface UpdateFeePayload {
  title?: string
  category?: string
  amount?: number
  dueDate?: string
  status?: string
}

export const feesApi = {
  getKpis: () => apiClient.get<FeeKpisData>("/fees/kpis"),

  getAllFees: (params?: { status?: string; category?: string }) =>
    apiClient.get<FeeRecordItem[]>("/fees/all", { params }),

  createFee: (payload: CreateFeePayload) =>
    apiClient.post<{ message: string; fee: FeeRecordItem }>("/fees", payload),

  updateFee: (id: string, payload: UpdateFeePayload) =>
    apiClient.patch<{ message: string; fee: FeeRecordItem }>(`/fees/${id}`, payload),

  deleteFee: (id: string) =>
    apiClient.delete<{ message: string }>(`/fees/${id}`),

  recordPayment: (id: string, amount?: number) =>
    apiClient.post<{ message: string; fee: FeeRecordItem }>(`/fees/${id}/record-payment`, { amount }),
}

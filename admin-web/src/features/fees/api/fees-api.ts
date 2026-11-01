import { apiClient } from "@/services/api/api-client"

export interface FeeRecordItem {
  id: string
  student_id: string
  title: string
  category: "TUITION" | "HOSTEL" | "EXAM" | "LIBRARY" | "OTHER"
  amount: number
  amount_paid: number
  due_date: string
  paid_at?: string | null
  status: "DUE" | "PARTIALLY_PAID" | "PAID" | "OVERDUE"
  receipt_number?: string | null
  academic_year: string
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

export const feesApi = {
  getKpis: () => apiClient.get<FeeKpisData>("/fees/kpis"),

  getAllFees: (params?: { status?: string; category?: string }) =>
    apiClient.get<FeeRecordItem[]>("/fees/all", { params }),

  createFee: (payload: CreateFeePayload) =>
    apiClient.post<{ message: string; fee: FeeRecordItem }>("/fees", payload),

  recordPayment: (id: string, amount?: number) =>
    apiClient.post<{ message: string; fee: FeeRecordItem }>(`/fees/${id}/record-payment`, { amount }),
}

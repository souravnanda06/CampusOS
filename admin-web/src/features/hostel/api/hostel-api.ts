import { apiClient } from "@/services/api/api-client"

export interface HostelAllocationRecord {
  id: string
  hostel_name: string
  room_number: string
  bed_number: string
  student_id: string
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
  status: string
  allocated_at: string
}

export interface HostelAssetIssue {
  id: string
  asset_id: string
  student_id: string
  issue_type: "DAMAGED" | "MISSING" | "REPAIR_NEEDED" | "REPLACEMENT_REQUESTED"
  description: string
  status: "REPORTED" | "ACKNOWLEDGED" | "IN_REPAIR" | "RESOLVED" | "CLOSED"
  reported_at: string
  resolved_at?: string | null
  resolution_notes?: string
  assetName?: string
  assetCode?: string
  hostelName?: string
  roomNumber?: string
  studentName?: string
  registrationNumber?: string
}

export interface HostelResidentRequest {
  id: string
  student_id: string
  request_type: string
  reason: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "COMPLETED"
  created_at: string
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
  warden_remarks?: string
}

export const hostelApi = {
  getKpis: () =>
    apiClient.get<{
      totalResidents: number
      totalAssets: number
      damagedAssets: number
      pendingRequests: number
      occupancyRate: number
    }>("/hostel/admin/kpis"),

  getAllocations: () =>
    apiClient.get<HostelAllocationRecord[]>("/hostel/admin/allocations"),

  getAssetIssues: () =>
    apiClient.get<HostelAssetIssue[]>("/hostel/warden/asset-issues"),

  getRequests: () =>
    apiClient.get<HostelResidentRequest[]>("/hostel/warden/requests"),

  actionRequest: (id: string, action: "APPROVE" | "REJECT" | "COMPLETE", remarks?: string) =>
    apiClient.post<{ message: string; request: HostelResidentRequest }>(
      `/hostel/warden/requests/${id}/action`,
      { action, remarks }
    ),

  actionAssetIssue: (
    id: string,
    status: "ACKNOWLEDGED" | "IN_REPAIR" | "RESOLVED" | "CLOSED",
    resolutionNotes?: string
  ) =>
    apiClient.post<{ message: string; issue: HostelAssetIssue }>(
      `/hostel/warden/asset-issues/${id}/action`,
      { status, resolutionNotes }
    ),
}

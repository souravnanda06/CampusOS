import { apiClient, ApiError } from "@/services/api/api-client"

export interface HostelAllocationRecord {
  id: string
  studentId: string
  hostelName: string
  block?: string | null
  roomNumber: string
  bedNumber?: string | null
  occupancyType?: string | null
  allocatedAt: string
  status: "ACTIVE" | "VACATED" | string
  notes?: string | null
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
}

export interface HostelAssetItem {
  id: string
  hostelName: string
  roomNumber: string
  assetCode: string
  assetName: string
  condition: "GOOD" | "FAIR" | "DAMAGED" | "MISSING" | "REPLACED" | string
  assignedStudentId?: string | null
  installedDate?: string | null
  lastInspectedAt?: string | null
  studentName?: string
  registrationNumber?: string
}

export interface HostelAssetIssue {
  id: string
  assetId: string
  studentId: string
  issueType: "DAMAGED" | "MISSING" | "REPAIR_NEEDED" | "REPLACEMENT_REQUESTED" | string
  description: string
  status: "REPORTED" | "ACKNOWLEDGED" | "IN_REPAIR" | "RESOLVED" | "CLOSED" | string
  resolutionNotes?: string | null
  reportedAt: string
  resolvedAt?: string | null
  assetName?: string
  assetCode?: string
  hostelName?: string
  roomNumber?: string
  studentName?: string
  registrationNumber?: string
}

export interface HostelResidentRequest {
  id: string
  studentId: string
  requestType: string
  preferredHostel?: string | null
  preferredRoom?: string | null
  reason: string
  status: "PENDING" | "APPROVED" | "REJECTED" | "COMPLETED" | string
  wardenId?: string | null
  wardenRemarks?: string | null
  createdAt: string
  updatedAt?: string | null
  studentName?: string
  registrationNumber?: string
  branch?: string
  year?: string | number
}

export interface UpsertAllocationPayload {
  studentId: string
  hostelName: string
  block?: string
  roomNumber: string
  bedNumber?: string
  occupancyType?: string
}

export interface CreateAssetPayload {
  hostelName: string
  roomNumber: string
  assetCode: string
  assetName: string
  condition?: string
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

  upsertAllocation: (payload: UpsertAllocationPayload) =>
    apiClient.post<{ message: string; allocation: HostelAllocationRecord }>(
      "/hostel/admin/allocations",
      payload
    ),

  vacateAllocation: (id: string) =>
    apiClient.post<{ message: string; allocation: HostelAllocationRecord }>(
      `/hostel/admin/allocations/${id}/vacate`,
      {}
    ),

  getAssets: async () => {
    try {
      return await apiClient.get<HostelAssetItem[]>("/hostel/admin/assets")
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) {
        return []
      }
      throw err
    }
  },

  createAsset: (payload: CreateAssetPayload) =>
    apiClient.post<{ message: string; asset: HostelAssetItem }>(
      "/hostel/admin/assets",
      payload
    ),

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

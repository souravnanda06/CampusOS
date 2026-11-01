import { apiClient } from '@/services/api/api-client';

export type NoticePriority = 'NORMAL' | 'HIGH' | 'URGENT';
export type NoticeCategory = 'GENERAL' | 'ACADEMIC' | 'EXAM' | 'HOSTEL' | 'MESS' | 'SECURITY' | 'EVENT' | 'FEE' | 'OTHER';
export type NoticeTargetType = 'ALL' | 'BRANCH' | 'YEAR' | 'STUDENT';
export type NoticeStatus = 'DRAFT' | 'PUBLISHED' | 'ARCHIVED' | 'EXPIRED';

export interface Notice {
  id: string;
  title: string;
  body?: string;
  content?: string;
  category: NoticeCategory;
  priority: NoticePriority;
  targetType: NoticeTargetType;
  targetValue?: string | null;
  actionType?: string | null;
  actionPayload?: string | null;
  expiresAt?: string | null;
  status: NoticeStatus;
  createdBy?: string;
  publishedBy?: string;
  createdAt: string;
  updatedAt?: string;
  recipientCount?: number;
  totalDeliveries?: number;
  readDeliveries?: number;
  pushAttempts?: number;
  deliveredCount?: number;
  failedCount?: number;
}

export interface NoticeDeliveryMetrics {
  noticeId: string;
  title: string;
  status: string;
  metrics: {
    recipients: number;
    pushAttempts: number;
    delivered: number;
    failed: number;
    read: number;
    unread: number;
  };
  deliveries: Array<{
    id: string;
    userId: string;
    status: string;
    isRead: boolean;
    deliveredAt: string | null;
    readAt: string | null;
    actionAt: string | null;
    pushAttempted: boolean;
    createdAt: string;
  }>;
}

export interface CreateNoticePayload {
  title: string;
  body: string;
  category: NoticeCategory;
  priority: NoticePriority;
  target_type: NoticeTargetType;
  target_value?: string;
  expires_at?: string;
  status?: NoticeStatus;
}

export const noticesApi = {
  getNotices: async (params?: { category?: string; priority?: string; status?: string; includeExpired?: boolean }): Promise<Notice[]> => {
    const query = new URLSearchParams();
    if (params?.category) query.append('category', params.category);
    if (params?.priority) query.append('priority', params.priority);
    if (params?.status) query.append('status', params.status);
    if (params?.includeExpired) query.append('includeExpired', 'true');
    const queryString = query.toString() ? `?${query.toString()}` : '';
    return apiClient.get<Notice[]>(`/notices${queryString}`);
  },

  getNoticeDetail: async (id: string): Promise<Notice> => {
    return apiClient.get<Notice>(`/notices/${id}`);
  },

  getNoticeDelivery: async (id: string): Promise<NoticeDeliveryMetrics> => {
    return apiClient.get<NoticeDeliveryMetrics>(`/notices/${id}/delivery`);
  },

  createNotice: async (payload: CreateNoticePayload): Promise<Notice> => {
    return apiClient.post<Notice>('/notices', payload);
  },

  updateNotice: async (id: string, payload: Partial<CreateNoticePayload>): Promise<Notice> => {
    return apiClient.patch<Notice>(`/notices/${id}`, payload);
  },

  archiveNotice: async (id: string): Promise<Notice> => {
    return apiClient.post<Notice>(`/notices/${id}/archive`);
  },
};

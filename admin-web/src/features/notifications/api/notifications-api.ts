import { apiClient } from '@/services/api/api-client';

export interface NotificationAnalytics {
  totalDispatched: number;
  deliveredCount: number;
  deliveryRate: number;
  readCount: number;
  readRate: number;
  actionedCount: number;
  actionRate: number;
  failedCount: number;
  registeredDevices: number;
}

export interface AdminNotificationItem {
  id: string;
  userId: string;
  noticeId?: string;
  title: string;
  body: string;
  notificationType: string;
  referenceId?: string;
  status: string;
  isRead: boolean;
  deliveredAt?: string | null;
  readAt?: string | null;
  actionAt?: string | null;
  createdAt: string;
  deepLinkRoute?: string;
  actionLabel?: string;
}

export interface NotificationsListResponse {
  notifications: AdminNotificationItem[];
  unreadCount: number;
}

export const notificationsApi = {
  getAnalytics: async (): Promise<NotificationAnalytics> => {
    return apiClient.get<NotificationAnalytics>('/notifications/admin/analytics');
  },

  getNotifications: async (unreadOnly = false): Promise<NotificationsListResponse> => {
    const query = unreadOnly ? '?unread=true' : '';
    return apiClient.get<NotificationsListResponse>(`/notifications${query}`);
  },

  markAsRead: async (id: string): Promise<{ message: string }> => {
    return apiClient.post<{ message: string }>(`/notifications/${id}/read`);
  },

  markAllAsRead: async (): Promise<{ message: string; readCount: number }> => {
    return apiClient.post<{ message: string; readCount: number }>('/notifications/read-all');
  },
};

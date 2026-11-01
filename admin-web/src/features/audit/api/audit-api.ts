import { apiClient } from '@/services/api/api-client';

export interface AuditRecord {
  id: string;
  source: 'WARDEN' | 'SECURITY' | 'COMPLAINT';
  timestamp: string;
  entityType: string;
  entityId: string;
  actorId?: string;
  actorName?: string;
  actorRole?: string;
  action: string;
  result?: string;
  studentName?: string;
  registrationNumber?: string;
  destination?: string;
  remarks?: string;
  ipAddress?: string;
}

export interface SecurityAuditItem {
  id: string;
  timestamp: string;
  operatorId?: string;
  operatorName?: string;
  studentId?: string;
  studentName?: string;
  registrationNumber?: string;
  operation: string;
  result: string;
  passType?: string;
  reason?: string;
  ipAddress?: string;
  remarks?: string;
}

export interface WardenActivityItem {
  id: string;
  entityType: string;
  entityId: string;
  actorId: string;
  action: string;
  remarks?: string;
  ipAddress?: string;
  timestamp: string;
  actorName?: string;
  actorRole?: string;
  studentName?: string;
  registrationNumber?: string;
  destination?: string;
}

export const auditApi = {
  getSecurityLogs: async (filter = 'ALL', limit = 100): Promise<SecurityAuditItem[]> => {
    return apiClient.get<SecurityAuditItem[]>(`/security/audit-logs?filter=${filter}&limit=${limit}`);
  },

  getWardenActivity: async (filter = 'ALL'): Promise<WardenActivityItem[]> => {
    return apiClient.get<WardenActivityItem[]>(`/warden/activity?filter=${filter}`);
  },

  getAllAuditLogs: async (): Promise<AuditRecord[]> => {
    const [security, warden] = await Promise.allSettled([
      auditApi.getSecurityLogs('ALL', 100),
      auditApi.getWardenActivity('ALL'),
    ]);

    const logs: AuditRecord[] = [];

    if (warden.status === 'fulfilled' && Array.isArray(warden.value)) {
      warden.value.forEach((w) => {
        logs.push({
          id: w.id,
          source: 'WARDEN',
          timestamp: w.timestamp,
          entityType: w.entityType,
          entityId: w.entityId,
          actorId: w.actorId,
          actorName: w.actorName || 'Staff Member',
          actorRole: w.actorRole || 'Staff',
          action: w.action,
          studentName: w.studentName,
          registrationNumber: w.registrationNumber,
          destination: w.destination,
          remarks: w.remarks,
          ipAddress: w.ipAddress,
        });
      });
    }

    if (security.status === 'fulfilled' && Array.isArray(security.value)) {
      security.value.forEach((s) => {
        logs.push({
          id: s.id,
          source: 'SECURITY',
          timestamp: s.timestamp,
          entityType: 'GATE_PASS',
          entityId: s.id,
          actorId: s.operatorId,
          actorName: s.operatorName || 'Security Guard',
          actorRole: 'Security',
          action: s.operation,
          result: s.result,
          studentName: s.studentName,
          registrationNumber: s.registrationNumber,
          remarks: s.remarks || s.reason,
          ipAddress: s.ipAddress,
        });
      });
    }

    // Sort descending by timestamp
    logs.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

    return logs;
  },
};

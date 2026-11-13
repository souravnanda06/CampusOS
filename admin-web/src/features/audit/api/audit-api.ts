import { apiClient } from '@/services/api/api-client';

export interface AuditRecord {
  id: string;
  source: 'GOVERNANCE' | 'WARDEN' | 'SECURITY' | string;
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

export interface UnifiedAuditItem {
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

export const auditApi = {
  getUnifiedAuditLogs: async (entityType = 'ALL', limit = 250): Promise<UnifiedAuditItem[]> => {
    return apiClient.get<UnifiedAuditItem[]>('/admin/audit-logs', {
      params: { entityType, limit },
    });
  },

  getSecurityLogs: async (filter = 'ALL', limit = 100): Promise<SecurityAuditItem[]> => {
    return apiClient.get<SecurityAuditItem[]>(`/security/audit-logs?filter=${filter}&limit=${limit}`);
  },

  getWardenActivity: async (filter = 'ALL'): Promise<Array<{
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
  }>> => {
    return apiClient.get(`/warden/activity?filter=${filter}`);
  },

  getAllAuditLogs: async (entityTypeFilter = 'ALL'): Promise<AuditRecord[]> => {
    const [unified, security] = await Promise.allSettled([
      auditApi.getUnifiedAuditLogs(entityTypeFilter, 250),
      entityTypeFilter === 'ALL' || entityTypeFilter === 'GATE_PASS'
        ? auditApi.getSecurityLogs('ALL', 100)
        : Promise.resolve([]),
    ]);

    const logs: AuditRecord[] = [];
    const seenIds = new Set<string>();

    if (unified.status === 'fulfilled' && Array.isArray(unified.value)) {
      unified.value.forEach((u) => {
        seenIds.add(u.id);
        logs.push({
          id: u.id,
          source: u.entityType === 'GATE_PASS' ? 'SECURITY' : 'GOVERNANCE',
          timestamp: u.timestamp,
          entityType: u.entityType,
          entityId: u.entityId,
          actorId: u.actorId,
          actorName: u.actorName || 'Staff Member',
          actorRole: u.actorRole || 'staff',
          action: u.action,
          remarks: u.remarks,
          ipAddress: u.ipAddress,
        });
      });
    } else {
      // Fallback for deployments without /admin/audit-logs
      try {
        const wardenLogs = await auditApi.getWardenActivity('ALL');
        wardenLogs.forEach((w) => {
          if (entityTypeFilter !== 'ALL' && w.entityType?.toUpperCase() !== entityTypeFilter) return;
          seenIds.add(w.id);
          logs.push({
            id: w.id,
            source: 'WARDEN',
            timestamp: w.timestamp,
            entityType: w.entityType,
            entityId: w.entityId,
            actorId: w.actorId,
            actorName: w.actorName || 'Staff Member',
            actorRole: w.actorRole || 'staff',
            action: w.action,
            studentName: w.studentName,
            registrationNumber: w.registrationNumber,
            destination: w.destination,
            remarks: w.remarks,
            ipAddress: w.ipAddress,
          });
        });
      } catch {
        // Ignore if unauthorized or unavailable
      }
    }

    if (security.status === 'fulfilled' && Array.isArray(security.value)) {
      security.value.forEach((s) => {
        if (seenIds.has(s.id)) return;
        logs.push({
          id: s.id,
          source: 'SECURITY',
          timestamp: s.timestamp,
          entityType: 'GATE_PASS',
          entityId: s.id,
          actorId: s.operatorId,
          actorName: s.operatorName || 'Security Guard',
          actorRole: 'guard',
          action: s.operation,
          result: s.result,
          studentName: s.studentName,
          registrationNumber: s.registrationNumber,
          remarks: s.remarks || s.reason,
          ipAddress: s.ipAddress,
        });
      });
    }

    logs.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
    return logs;
  },
};

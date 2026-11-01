import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import { auditApi, type AuditRecord } from './api/audit-api';
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import {
  FileText,
  Shield,
  Download,
  Search,
  Filter,
  RefreshCw,
  CheckCircle2,
  AlertTriangle,
  Clock,
  User,
} from 'lucide-react';

export const AuditPage: React.FC = () => {
  const [sourceFilter, setSourceFilter] = React.useState<string>('ALL');
  const [searchQuery, setSearchQuery] = React.useState('');

  const {
    data: auditLogs,
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ['audit-logs'],
    queryFn: () => auditApi.getAllAuditLogs(),
  });

  const filteredLogs = React.useMemo(() => {
    if (!auditLogs) return [];
    return auditLogs.filter((log) => {
      if (sourceFilter !== 'ALL' && log.source !== sourceFilter) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesActor = log.actorName?.toLowerCase().includes(q);
        const matchesStudent = log.studentName?.toLowerCase().includes(q);
        const matchesReg = log.registrationNumber?.toLowerCase().includes(q);
        const matchesAction = log.action?.toLowerCase().includes(q);
        const matchesRemarks = log.remarks?.toLowerCase().includes(q);
        return matchesActor || matchesStudent || matchesReg || matchesAction || matchesRemarks;
      }
      return true;
    });
  }, [auditLogs, sourceFilter, searchQuery]);

  const handleExportCSV = () => {
    if (!filteredLogs.length) return;
    const headers = ['Timestamp', 'Source', 'Action', 'Result', 'Actor', 'Role', 'Student', 'Reg No', 'IP Address', 'Remarks'];
    const rows = filteredLogs.map((l) => [
      `"${l.timestamp}"`,
      `"${l.source}"`,
      `"${l.action}"`,
      `"${l.result || ''}"`,
      `"${l.actorName || ''}"`,
      `"${l.actorRole || ''}"`,
      `"${l.studentName || ''}"`,
      `"${l.registrationNumber || ''}"`,
      `"${l.ipAddress || ''}"`,
      `"${(l.remarks || '').replace(/"/g, '""')}"`,
    ]);
    const csvContent = [headers.join(','), ...rows.map((r) => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `campusos-audit-ledger-${new Date().toISOString().slice(0, 10)}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const getActionBadgeVariant = (action: string, result?: string) => {
    if (result === 'FAILED' || action.includes('FAILED') || action.includes('REJECT')) {
      return 'destructive';
    }
    if (action.includes('APPROV') || result === 'SUCCESS' || action.includes('SCANNED_IN')) {
      return 'default';
    }
    if (action.includes('EXIT') || action.includes('SCANNED_OUT')) {
      return 'warning';
    }
    return 'secondary';
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Institutional Audit Ledger"
        subtitle="Chronological audit records covering security gates, hostel warden authorizations, and perimeter events."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-1.5">
              <RefreshCw className="h-4 w-4" />
              <span>Refresh Ledger</span>
            </Button>
            <Button
              size="sm"
              onClick={handleExportCSV}
              disabled={!filteredLogs.length}
              className="gap-1.5"
            >
              <Download className="h-4 w-4" />
              <span>Export CSV</span>
            </Button>
          </div>
        }
      />

      {/* Filter and Search Bar */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-lg border border-border bg-card p-3 shadow-2xs">
        <div className="flex flex-wrap items-center gap-3">
          <div className="relative w-64">
            <Search className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-muted-foreground" />
            <Input
              placeholder="Search actor, student, reg no, remarks..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-8 text-xs h-8"
            />
          </div>

          <div className="flex items-center gap-2">
            <Filter className="h-3.5 w-3.5 text-muted-foreground" />
            <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Stream:
            </span>
            <select
              value={sourceFilter}
              onChange={(e) => setSourceFilter(e.target.value)}
              className="rounded-md border border-input bg-background px-2.5 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
            >
              <option value="ALL">All Streams</option>
              <option value="SECURITY">Perimeter Security & Gates</option>
              <option value="WARDEN">Hostel & Leave Approvals</option>
            </select>
          </div>
        </div>

        <div className="text-xs text-muted-foreground font-mono">
          {filteredLogs.length} audit events indexed
        </div>
      </div>

      {/* Audit Log Table */}
      {isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
        </div>
      ) : error ? (
        <ErrorState
          title="Could not load audit ledger"
          message={error instanceof Error ? error.message : 'Unknown server error'}
          onRetry={() => refetch()}
        />
      ) : filteredLogs.length === 0 ? (
        <EmptyState
          icon={FileText}
          title="No audit events found"
          description="Adjust your search query or stream filters to view activity records."
        />
      ) : (
        <div className="rounded-lg border border-border bg-card shadow-xs overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-border bg-muted/40 text-muted-foreground uppercase text-[10px] font-mono tracking-wider">
                  <th className="py-2.5 px-4 font-semibold">Timestamp</th>
                  <th className="py-2.5 px-4 font-semibold">Stream</th>
                  <th className="py-2.5 px-4 font-semibold">Action / Event</th>
                  <th className="py-2.5 px-4 font-semibold">Actor / Operator</th>
                  <th className="py-2.5 px-4 font-semibold">Student / Subject</th>
                  <th className="py-2.5 px-4 font-semibold">IP / Location</th>
                  <th className="py-2.5 px-4 font-semibold">Remarks & Context</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/60">
                {filteredLogs.map((log: AuditRecord) => (
                  <tr key={log.id} className="hover:bg-muted/30 transition-colors">
                    <td className="py-3 px-4 whitespace-nowrap">
                      <div className="font-mono text-foreground font-medium text-[11px]">
                        {formatDate(log.timestamp)}
                      </div>
                      <div className="text-[10px] text-muted-foreground">
                        {formatRelativeTime(log.timestamp)}
                      </div>
                    </td>

                    <td className="py-3 px-4">
                      <Badge
                        variant={log.source === 'SECURITY' ? 'default' : 'secondary'}
                        className="text-[9px] uppercase font-mono px-1.5 py-0"
                      >
                        {log.source}
                      </Badge>
                    </td>

                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5">
                        <Badge
                          variant={getActionBadgeVariant(log.action, log.result)}
                          className="text-[10px] uppercase font-mono px-1.5 py-0"
                        >
                          {log.action}
                        </Badge>
                        {log.result && log.result !== 'SUCCESS' && (
                          <span className="text-[10px] text-destructive font-mono font-medium">
                            [{log.result}]
                          </span>
                        )}
                      </div>
                    </td>

                    <td className="py-3 px-4">
                      <div className="flex items-center gap-1.5">
                        <User className="h-3 w-3 text-muted-foreground" />
                        <div>
                          <span className="font-medium text-foreground">
                            {log.actorName || 'System'}
                          </span>
                          {log.actorRole && (
                            <span className="text-[10px] text-muted-foreground block capitalize">
                              {log.actorRole}
                            </span>
                          )}
                        </div>
                      </div>
                    </td>

                    <td className="py-3 px-4">
                      {log.studentName ? (
                        <div>
                          <span className="font-medium text-foreground">
                            {log.studentName}
                          </span>
                          {log.registrationNumber && (
                            <span className="text-[10px] font-mono text-muted-foreground block">
                              {log.registrationNumber}
                            </span>
                          )}
                        </div>
                      ) : (
                        <span className="text-muted-foreground font-mono text-[11px]">—</span>
                      )}
                    </td>

                    <td className="py-3 px-4 font-mono text-[11px] text-muted-foreground whitespace-nowrap">
                      {log.ipAddress || '127.0.0.1'}
                    </td>

                    <td className="py-3 px-4 text-muted-foreground max-w-[240px] truncate" title={log.remarks}>
                      {log.remarks || (log.destination ? `Destination: ${log.destination}` : '—')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};

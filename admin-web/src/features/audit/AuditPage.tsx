import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import { ColumnDef } from '@tanstack/react-table';
import { auditApi, type AuditRecord } from './api/audit-api';
import { PageHeader } from '@/components/ui/page-header';
import { DataTable } from '@/components/data-table/data-table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import { Download, RefreshCw } from 'lucide-react';

export const AuditPage: React.FC = () => {
  const [entityFilter, setEntityFilter] = React.useState<string>('ALL');

  const {
    data: auditLogs = [],
    isLoading,
    error,
    refetch,
  } = useQuery({
    queryKey: ['audit-logs', entityFilter],
    queryFn: () => auditApi.getAllAuditLogs(entityFilter),
  });

  const handleExportCSV = () => {
    if (!auditLogs.length) return;
    const headers = [
      'Timestamp',
      'Entity Type',
      'Action',
      'Result',
      'Actor',
      'Role',
      'Entity ID',
      'IP Address',
      'Remarks',
    ];
    const rows = auditLogs.map((l) => [
      `"${l.timestamp}"`,
      `"${l.entityType}"`,
      `"${l.action}"`,
      `"${l.result || ''}"`,
      `"${l.actorName || ''}"`,
      `"${l.actorRole || ''}"`,
      `"${l.entityId}"`,
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
    if (result === 'FAILED' || action.includes('FAILED') || action.includes('REJECT') || action.includes('DELETE')) {
      return 'destructive';
    }
    if (action.includes('APPROV') || result === 'SUCCESS' || action.includes('CREATE') || action.includes('RESOLV')) {
      return 'success';
    }
    if (action.includes('EXIT') || action.includes('CANCEL') || action.includes('VACATE')) {
      return 'warning';
    }
    return 'secondary';
  };

  const columns: ColumnDef<AuditRecord>[] = [
    {
      accessorKey: 'entityType',
      header: 'Domain / Action',
      cell: ({ row }) => (
        <div className="space-y-1">
          <div className="flex items-center gap-1.5 flex-wrap">
            <Badge variant="outline" className="text-[10px] font-mono">
              {row.original.entityType}
            </Badge>
            <Badge
              variant={getActionBadgeVariant(row.original.action, row.original.result)}
              className="text-[10px] font-mono"
            >
              {row.original.action}
            </Badge>
          </div>
          <p className="text-[10px] font-mono text-muted-foreground">
            Entity: {row.original.entityId.slice(0, 12)}
          </p>
        </div>
      ),
    },
    {
      accessorKey: 'actorName',
      header: 'Actor',
      cell: ({ row }) => (
        <div className="space-y-0.5">
          <p className="text-xs font-semibold text-foreground">{row.original.actorName || 'System'}</p>
          <p className="text-[10px] font-mono uppercase text-muted-foreground">
            {row.original.actorRole || 'system'}
          </p>
        </div>
      ),
    },
    {
      accessorKey: 'remarks',
      header: 'Audit Remarks',
      cell: ({ row }) => (
        <span className="text-xs text-foreground line-clamp-2 max-w-md block">
          {row.original.remarks || '—'}
        </span>
      ),
    },
    {
      accessorKey: 'ipAddress',
      header: 'Source IP',
      cell: ({ row }) => (
        <span className="font-mono text-[11px] text-muted-foreground">
          {row.original.ipAddress || '—'}
        </span>
      ),
    },
    {
      accessorKey: 'timestamp',
      header: 'Timestamp',
      cell: ({ row }) => (
        <div className="space-y-0.5 text-right sm:text-left">
          <p className="font-mono text-xs text-foreground">
            {formatRelativeTime(row.original.timestamp)}
          </p>
          <p className="font-mono text-[10px] text-muted-foreground">
            {formatDate(row.original.timestamp)}
          </p>
        </div>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <PageHeader
        title="Institutional Audit Ledger"
        description="Unified governance & perimeter audit trail spanning user accounts, fees, hostel operations, leaves, complaints, and gate security."
        badge={
          <span className="text-xs font-mono text-muted-foreground">
            {auditLogs.length} Events
          </span>
        }
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={() => refetch()} className="gap-1.5 text-xs">
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={handleExportCSV}
              disabled={!auditLogs.length}
              className="gap-1.5 text-xs"
            >
              <Download className="h-3.5 w-3.5" />
              Export CSV
            </Button>
          </div>
        }
      />

      <DataTable
        columns={columns}
        data={auditLogs}
        isLoading={isLoading}
        error={error}
        onRetry={refetch}
        searchPlaceholder="Search actor, action, domain, IP, or remarks..."
        emptyTitle="No Audit Records"
        emptyDescription="No governance or security events match the selected domain filter."
        toolbarSlot={
          <Select value={entityFilter} onValueChange={setEntityFilter}>
            <SelectTrigger className="w-52 h-8 text-xs bg-card">
              <SelectValue placeholder="Filter domain..." />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Domains</SelectItem>
              <SelectItem value="USER_MANAGEMENT">User & Role Admin</SelectItem>
              <SelectItem value="STUDENT_REGISTRATION">Student Approvals</SelectItem>
              <SelectItem value="FEE_RECORD">Fee Adjustments</SelectItem>
              <SelectItem value="HOSTEL_ALLOCATION">Hostel Allocations</SelectItem>
              <SelectItem value="HOSTEL_ASSET">Hostel Assets</SelectItem>
              <SelectItem value="LEAVE_REQUEST">Leave Approvals</SelectItem>
              <SelectItem value="GATE_PASS">Perimeter Gate Passes</SelectItem>
              <SelectItem value="COMPLAINT">Complaints</SelectItem>
              <SelectItem value="CLASS_UPDATE">Class Updates</SelectItem>
            </SelectContent>
          </Select>
        }
      />
    </div>
  );
};

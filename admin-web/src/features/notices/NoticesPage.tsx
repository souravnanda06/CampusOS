import * as React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  noticesApi,
  type Notice,
} from './api/notices-api';
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { ConfirmDialog } from '@/components/feedback/confirm-dialog';
import { useToast } from '@/components/ui/toast';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import { CreateNoticeDialog } from './components/create-notice-dialog';
import { NoticeDeliverySheet } from './components/notice-delivery-sheet';
import {
  Megaphone,
  Plus,
  Users,
  Archive,
  BarChart3,
  Calendar,
} from 'lucide-react';

export const NoticesPage: React.FC = () => {
  const queryClient = useQueryClient();
  const { addToast } = useToast();

  const [categoryFilter, setCategoryFilter] = React.useState<string>('ALL');
  const [priorityFilter, setPriorityFilter] = React.useState<string>('ALL');
  const [statusFilter, setStatusFilter] = React.useState<string>('ALL');
  const [createDialogOpen, setCreateDialogOpen] = React.useState(false);
  const [selectedNoticeForDelivery, setSelectedNoticeForDelivery] = React.useState<Notice | null>(null);
  const [noticeToArchive, setNoticeToArchive] = React.useState<Notice | null>(null);

  const { data: notices, isLoading, error, refetch } = useQuery({
    queryKey: ['notices', categoryFilter, priorityFilter, statusFilter],
    queryFn: () =>
      noticesApi.getNotices({
        category: categoryFilter !== 'ALL' ? categoryFilter : undefined,
        priority: priorityFilter !== 'ALL' ? priorityFilter : undefined,
        status: statusFilter !== 'ALL' ? statusFilter : undefined,
        includeExpired: true,
      }),
  });

  const archiveMutation = useMutation({
    mutationFn: (id: string) => noticesApi.archiveNotice(id),
    onSuccess: () => {
      addToast({
        type: 'success',
        title: 'Notice Archived',
        message: 'The notice has been moved to the institutional archive.',
      });
      queryClient.invalidateQueries({ queryKey: ['notices'] });
      setNoticeToArchive(null);
    },
    onError: (err: unknown) => {
      addToast({
        type: 'error',
        title: 'Archive Failed',
        message: err instanceof Error ? err.message : 'Could not archive notice',
      });
    },
  });

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notices & Broadcasts"
        subtitle="Institution-wide announcements, targeted cohort dispatches, and push delivery metrics."
        actions={
          <Button onClick={() => setCreateDialogOpen(true)} className="gap-2">
            <Plus className="h-4 w-4" />
            <span>Broadcast Notice</span>
          </Button>
        }
      />

      {/* Filter Bar */}
      <div className="flex flex-wrap items-center gap-3 rounded-lg border border-border bg-card p-3 shadow-2xs">
        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Category:
          </span>
          <select
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
            className="rounded-md border border-input bg-background px-2.5 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
          >
            <option value="ALL">All Categories</option>
            <option value="GENERAL">General</option>
            <option value="ACADEMIC">Academic</option>
            <option value="EXAM">Exam</option>
            <option value="HOSTEL">Hostel</option>
            <option value="MESS">Mess</option>
            <option value="SECURITY">Security</option>
            <option value="EVENT">Event</option>
            <option value="FEE">Fee</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Priority:
          </span>
          <select
            value={priorityFilter}
            onChange={(e) => setPriorityFilter(e.target.value)}
            className="rounded-md border border-input bg-background px-2.5 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
          >
            <option value="ALL">All Priorities</option>
            <option value="NORMAL">Normal</option>
            <option value="HIGH">High</option>
            <option value="URGENT">Urgent</option>
          </select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Status:
          </span>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-md border border-input bg-background px-2.5 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
          >
            <option value="ALL">All Statuses</option>
            <option value="PUBLISHED">Published</option>
            <option value="DRAFT">Draft</option>
            <option value="ARCHIVED">Archived</option>
          </select>
        </div>

        <div className="ml-auto text-xs text-muted-foreground font-mono">
          {notices ? `${notices.length} notices found` : 'Loading...'}
        </div>
      </div>

      {/* Main Content Area */}
      {isLoading ? (
        <div className="space-y-4">
          <Skeleton className="h-28 w-full" />
          <Skeleton className="h-28 w-full" />
          <Skeleton className="h-28 w-full" />
        </div>
      ) : error ? (
        <ErrorState
          title="Could not load notices"
          message={error instanceof Error ? error.message : 'Unknown server error'}
          onRetry={() => refetch()}
        />
      ) : !notices || notices.length === 0 ? (
        <EmptyState
          icon={Megaphone}
          title="No notices found"
          description="Create your first institutional broadcast or adjust your category and status filters."
          action={{
            label: 'Create Notice',
            onClick: () => setCreateDialogOpen(true),
          }}
        />
      ) : (
        <div className="space-y-3">
          {notices.map((n) => (
            <div
              key={n.id}
              className="group relative flex flex-col md:flex-row md:items-center justify-between gap-4 rounded-lg border border-border bg-card p-4 transition-all hover:border-primary/40 hover:shadow-xs"
            >
              <div className="space-y-1.5 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h3 className="font-semibold text-sm text-foreground">
                    {n.title}
                  </h3>
                  <Badge
                    variant={
                      n.priority === 'URGENT'
                        ? 'destructive'
                        : n.priority === 'HIGH'
                        ? 'warning'
                        : 'outline'
                    }
                    className="text-[10px] uppercase font-mono px-1.5 py-0"
                  >
                    {n.priority}
                  </Badge>
                  <Badge variant="secondary" className="text-[10px] uppercase px-1.5 py-0">
                    {n.category}
                  </Badge>
                  <Badge
                    variant={
                      n.status === 'PUBLISHED'
                        ? 'default'
                        : n.status === 'ARCHIVED'
                        ? 'outline'
                        : 'secondary'
                    }
                    className="text-[10px] uppercase px-1.5 py-0"
                  >
                    {n.status}
                  </Badge>
                </div>

                <p className="text-xs text-muted-foreground line-clamp-2 pr-4">
                  {n.body || n.content}
                </p>

                <div className="flex flex-wrap items-center gap-4 text-[11px] text-muted-foreground pt-1">
                  <div className="flex items-center gap-1 font-mono">
                    <Users className="h-3 w-3 text-primary/70" />
                    <span>
                      Target: {n.targetType}
                      {n.targetValue ? ` (${n.targetValue})` : ''}
                    </span>
                  </div>
                  <div className="flex items-center gap-1">
                    <Calendar className="h-3 w-3" />
                    <span>Dispatched {formatDate(n.createdAt)} ({formatRelativeTime(n.createdAt)})</span>
                  </div>
                  {n.expiresAt && (
                    <span className="text-amber-600 dark:text-amber-400 font-mono text-[10px]">
                      Expires: {formatDate(n.expiresAt)}
                    </span>
                  )}
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-2 shrink-0 border-t md:border-t-0 pt-3 md:pt-0 border-border">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setSelectedNoticeForDelivery(n)}
                  className="gap-1.5 text-xs h-8"
                >
                  <BarChart3 className="h-3.5 w-3.5 text-blue-500" />
                  <span>Telemetry</span>
                </Button>

                {n.status !== 'ARCHIVED' && (
                  <Button
                    size="sm"
                    variant="ghost"
                    onClick={() => setNoticeToArchive(n)}
                    className="text-muted-foreground hover:text-destructive h-8 px-2"
                    title="Archive Notice"
                  >
                    <Archive className="h-4 w-4" />
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Dialogs & Drawers */}
      <CreateNoticeDialog
        open={createDialogOpen}
        onOpenChange={setCreateDialogOpen}
        onSuccess={() => queryClient.invalidateQueries({ queryKey: ['notices'] })}
      />

      <NoticeDeliverySheet
        notice={selectedNoticeForDelivery}
        open={!!selectedNoticeForDelivery}
        onOpenChange={(open) => !open && setSelectedNoticeForDelivery(null)}
      />

      <ConfirmDialog
        open={!!noticeToArchive}
        onOpenChange={(open) => !open && setNoticeToArchive(null)}
        title="Archive Notice"
        description={`Are you sure you want to archive "${noticeToArchive?.title}"? It will no longer appear on active student noticeboards.`}
        confirmLabel="Archive"
        variant="destructive"
        onConfirm={() => {
          if (noticeToArchive) archiveMutation.mutate(noticeToArchive.id);
        }}
        isLoading={archiveMutation.isPending}
      />
    </div>
  );
};

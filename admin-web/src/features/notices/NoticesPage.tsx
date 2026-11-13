import * as React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { noticesApi, type Notice } from './api/notices-api';
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
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
  Pencil,
  Send,
} from 'lucide-react';

export const NoticesPage: React.FC = () => {
  const queryClient = useQueryClient();
  const { addToast } = useToast();

  const [categoryFilter, setCategoryFilter] = React.useState<string>('ALL');
  const [priorityFilter, setPriorityFilter] = React.useState<string>('ALL');
  const [statusFilter, setStatusFilter] = React.useState<string>('ALL');
  const [dialogOpen, setDialogOpen] = React.useState(false);
  const [noticeToEdit, setNoticeToEdit] = React.useState<Notice | null>(null);
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

  const publishMutation = useMutation({
    mutationFn: (id: string) => noticesApi.updateNotice(id, { status: 'PUBLISHED' }),
    onSuccess: () => {
      addToast({
        type: 'success',
        title: 'Notice Published',
        message: 'Draft broadcast is now live to target recipients.',
      });
      queryClient.invalidateQueries({ queryKey: ['notices'] });
    },
    onError: (err: unknown) => {
      addToast({
        type: 'error',
        title: 'Publish Failed',
        message: err instanceof Error ? err.message : 'Could not publish notice',
      });
    },
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
          <Button
            onClick={() => {
              setNoticeToEdit(null);
              setDialogOpen(true);
            }}
            className="gap-2"
          >
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
          <Select value={categoryFilter} onValueChange={setCategoryFilter}>
            <SelectTrigger className="w-[140px] h-8 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Categories</SelectItem>
              <SelectItem value="GENERAL">General</SelectItem>
              <SelectItem value="ACADEMIC">Academic</SelectItem>
              <SelectItem value="EXAM">Exam</SelectItem>
              <SelectItem value="HOSTEL">Hostel</SelectItem>
              <SelectItem value="MESS">Mess</SelectItem>
              <SelectItem value="SECURITY">Security</SelectItem>
              <SelectItem value="EVENT">Event</SelectItem>
              <SelectItem value="FEE">Fee</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Priority:
          </span>
          <Select value={priorityFilter} onValueChange={setPriorityFilter}>
            <SelectTrigger className="w-[130px] h-8 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Priorities</SelectItem>
              <SelectItem value="NORMAL">Normal</SelectItem>
              <SelectItem value="HIGH">High</SelectItem>
              <SelectItem value="URGENT">Urgent</SelectItem>
            </SelectContent>
          </Select>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Status:
          </span>
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-[130px] h-8 text-xs">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="ALL">All Statuses</SelectItem>
              <SelectItem value="PUBLISHED">Published</SelectItem>
              <SelectItem value="DRAFT">Draft</SelectItem>
              <SelectItem value="ARCHIVED">Archived</SelectItem>
            </SelectContent>
          </Select>
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
            onClick: () => {
              setNoticeToEdit(null);
              setDialogOpen(true);
            },
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
                  <h3 className="font-semibold text-sm text-foreground">{n.title}</h3>
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
                    <span>
                      Dispatched {formatDate(n.createdAt)} ({formatRelativeTime(n.createdAt)})
                    </span>
                  </div>
                  {n.expiresAt && (
                    <span className="text-amber-600 dark:text-amber-400 font-mono text-[10px]">
                      Expires: {formatDate(n.expiresAt)}
                    </span>
                  )}
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center gap-2 shrink-0 border-t md:border-t-0 pt-3 md:pt-0 border-border flex-wrap">
                {n.status === 'DRAFT' && (
                  <Button
                    size="sm"
                    onClick={() => publishMutation.mutate(n.id)}
                    loading={publishMutation.isPending && publishMutation.variables === n.id}
                    className="gap-1.5 text-xs h-8"
                  >
                    <Send className="h-3.5 w-3.5" />
                    <span>Publish</span>
                  </Button>
                )}

                {n.status !== 'ARCHIVED' && (
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => {
                      setNoticeToEdit(n);
                      setDialogOpen(true);
                    }}
                    className="gap-1.5 text-xs h-8"
                  >
                    <Pencil className="h-3.5 w-3.5" />
                    <span>Edit</span>
                  </Button>
                )}

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
        open={dialogOpen}
        onOpenChange={(open) => {
          setDialogOpen(open);
          if (!open) setNoticeToEdit(null);
        }}
        noticeToEdit={noticeToEdit}
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

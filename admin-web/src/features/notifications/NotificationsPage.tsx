import * as React from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { notificationsApi, type AdminNotificationItem } from './api/notifications-api';
import { PageHeader } from '@/components/ui/page-header';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { EmptyState } from '@/components/ui/empty-state';
import { ErrorState } from '@/components/ui/error-state';
import { useToast } from '@/components/ui/toast';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import {
  Bell,
  Smartphone,
  CheckCheck,
  Send,
  Eye,
  CheckCircle2,
  AlertTriangle,
  ArrowUpRight,
  Filter,
} from 'lucide-react';
import { Link } from 'react-router-dom';

export const NotificationsPage: React.FC = () => {
  const queryClient = useQueryClient();
  const { addToast } = useToast();
  const [unreadOnly, setUnreadOnly] = React.useState(false);

  const {
    data: analytics,
    isLoading: analyticsLoading,
    error: analyticsError,
  } = useQuery({
    queryKey: ['notification-analytics'],
    queryFn: () => notificationsApi.getAnalytics(),
  });

  const {
    data: notificationsData,
    isLoading: notificationsLoading,
    error: notificationsError,
    refetch,
  } = useQuery({
    queryKey: ['notifications-list', unreadOnly],
    queryFn: () => notificationsApi.getNotifications(unreadOnly),
  });

  const markAllMutation = useMutation({
    mutationFn: () => notificationsApi.markAllAsRead(),
    onSuccess: (data) => {
      addToast({
        type: 'success',
        title: 'All Caught Up',
        message: data.message || 'Marked notifications as read',
      });
      queryClient.invalidateQueries({ queryKey: ['notifications-list'] });
      queryClient.invalidateQueries({ queryKey: ['notification-analytics'] });
    },
    onError: (err: unknown) => {
      addToast({
        type: 'error',
        title: 'Action Failed',
        message: err instanceof Error ? err.message : 'Failed to mark notifications',
      });
    },
  });

  const markOneMutation = useMutation({
    mutationFn: (id: string) => notificationsApi.markAsRead(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['notifications-list'] });
      queryClient.invalidateQueries({ queryKey: ['notification-analytics'] });
    },
  });

  const getBadgeVariant = (type: string) => {
    switch (type.toUpperCase()) {
      case 'URGENT':
      case 'SECURITY':
      case 'GATE_PASS':
        return 'destructive';
      case 'FEE':
      case 'DOCUMENT':
        return 'warning';
      case 'ACADEMIC':
      case 'CLASS_UPDATE':
        return 'default';
      default:
        return 'secondary';
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        title="Notification Hub & Push Telemetry"
        subtitle="Institutional multi-channel notification engine, device token registry, and delivery confirmation metrics."
        actions={
          <Button
            variant="outline"
            size="sm"
            onClick={() => markAllMutation.mutate()}
            disabled={markAllMutation.isPending || !notificationsData?.unreadCount}
            className="gap-2"
          >
            <CheckCheck className="h-4 w-4" />
            <span>Mark All Read</span>
          </Button>
        }
      />

      {/* Analytics KPI Row */}
      {analyticsLoading ? (
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-24 w-full" />
          ))}
        </div>
      ) : analyticsError ? (
        <div className="rounded-md bg-destructive/10 p-3 text-xs text-destructive">
          Failed to load push analytics.
        </div>
      ) : analytics ? (
        <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div className="rounded-lg border border-border bg-card p-3 shadow-2xs">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Send className="h-3.5 w-3.5 text-blue-500" />
              <span>Total Dispatches</span>
            </div>
            <div className="mt-1 text-2xl font-bold font-mono">
              {analytics.totalDispatched.toLocaleString()}
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              Across all channels
            </div>
          </div>

          <div className="rounded-lg border border-border bg-card p-3 shadow-2xs">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" />
              <span>Delivery Rate</span>
            </div>
            <div className="mt-1 text-2xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
              {analytics.deliveryRate}%
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              {analytics.deliveredCount.toLocaleString()} delivered
            </div>
          </div>

          <div className="rounded-lg border border-border bg-card p-3 shadow-2xs">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Eye className="h-3.5 w-3.5 text-indigo-500" />
              <span>Read Rate</span>
            </div>
            <div className="mt-1 text-2xl font-bold font-mono text-indigo-600 dark:text-indigo-400">
              {analytics.readRate}%
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              {analytics.readCount.toLocaleString()} confirmed reads
            </div>
          </div>

          <div className="rounded-lg border border-border bg-card p-3 shadow-2xs">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <CheckCheck className="h-3.5 w-3.5 text-violet-500" />
              <span>Action Rate</span>
            </div>
            <div className="mt-1 text-2xl font-bold font-mono text-violet-600 dark:text-violet-400">
              {analytics.actionRate}%
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              {analytics.actionedCount.toLocaleString()} acted on
            </div>
          </div>

          <div className="rounded-lg border border-border bg-card p-3 shadow-2xs">
            <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
              <Smartphone className="h-3.5 w-3.5 text-amber-500" />
              <span>Active Devices</span>
            </div>
            <div className="mt-1 text-2xl font-bold font-mono text-amber-600 dark:text-amber-400">
              {analytics.registeredDevices.toLocaleString()}
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              FCM / APNs registered tokens
            </div>
          </div>
        </div>
      ) : null}

      {/* Notifications Filter Bar */}
      <div className="flex items-center justify-between rounded-lg border border-border bg-card p-3 shadow-2xs">
        <div className="flex items-center gap-2">
          <Filter className="h-3.5 w-3.5 text-muted-foreground" />
          <span className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            Feed Filter:
          </span>
          <Button
            size="sm"
            variant={!unreadOnly ? 'secondary' : 'ghost'}
            className="text-xs h-7"
            onClick={() => setUnreadOnly(false)}
          >
            All Activity
          </Button>
          <Button
            size="sm"
            variant={unreadOnly ? 'secondary' : 'ghost'}
            className="text-xs h-7"
            onClick={() => setUnreadOnly(true)}
          >
            Unread Only ({notificationsData?.unreadCount || 0})
          </Button>
        </div>

        <div className="text-xs text-muted-foreground font-mono">
          Last 50 system notifications
        </div>
      </div>

      {/* Notification Stream */}
      {notificationsLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : notificationsError ? (
        <ErrorState
          title="Could not load notifications"
          message={
            notificationsError instanceof Error
              ? notificationsError.message
              : 'Unknown error occurred'
          }
          onRetry={() => refetch()}
        />
      ) : !notificationsData?.notifications || notificationsData.notifications.length === 0 ? (
        <EmptyState
          icon={Bell}
          title="No notifications in feed"
          description={
            unreadOnly
              ? 'You have caught up with all incoming system events.'
              : 'No notification records exist currently.'
          }
        />
      ) : (
        <div className="space-y-2.5">
          {notificationsData.notifications.map((item: AdminNotificationItem) => (
            <div
              key={item.id}
              className={`flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-lg border p-3.5 transition-colors ${
                !item.isRead
                  ? 'border-primary/40 bg-primary/5 dark:bg-primary/10'
                  : 'border-border bg-card'
              }`}
            >
              <div className="space-y-1 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <Badge
                    variant={getBadgeVariant(item.notificationType)}
                    className="text-[10px] uppercase font-mono px-1.5 py-0"
                  >
                    {item.notificationType}
                  </Badge>
                  <span className="font-semibold text-xs text-foreground">
                    {item.title}
                  </span>
                  {!item.isRead && (
                    <span className="h-2 w-2 rounded-full bg-primary animate-pulse" />
                  )}
                </div>

                <p className="text-xs text-muted-foreground line-clamp-2">
                  {item.body}
                </p>

                <div className="flex items-center gap-3 text-[10px] text-muted-foreground font-mono">
                  <span>{formatDate(item.createdAt)}</span>
                  <span>({formatRelativeTime(item.createdAt)})</span>
                  {item.status && (
                    <span className="uppercase text-[9px] px-1 bg-muted rounded">
                      Status: {item.status}
                    </span>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2 shrink-0 border-t sm:border-t-0 pt-2 sm:pt-0 border-border">
                {item.deepLinkRoute && (
                  <Link
                    to={
                      item.notificationType === 'COMPLAINT'
                        ? '/complaints'
                        : item.notificationType === 'DOCUMENT'
                        ? '/documents'
                        : item.notificationType === 'FEE'
                        ? '/fees'
                        : item.notificationType === 'HOSTEL'
                        ? '/hostel'
                        : item.notificationType === 'VISITOR'
                        ? '/visitors'
                        : item.notificationType === 'CLASS_UPDATE'
                        ? '/academic'
                        : '/notices'
                    }
                  >
                    <Button variant="ghost" size="sm" className="h-7 text-xs gap-1">
                      <span>{item.actionLabel || 'Inspect'}</span>
                      <ArrowUpRight className="h-3 w-3" />
                    </Button>
                  </Link>
                )}

                {!item.isRead && (
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-7 text-xs"
                    onClick={() => markOneMutation.mutate(item.id)}
                    disabled={markOneMutation.isPending}
                  >
                    Mark Read
                  </Button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

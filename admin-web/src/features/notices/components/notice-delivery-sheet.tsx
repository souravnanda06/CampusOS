import * as React from 'react';
import { useQuery } from '@tanstack/react-query';
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import { Skeleton } from '@/components/ui/skeleton';
import { formatDate, formatRelativeTime } from '@/lib/utils';
import { noticesApi, type Notice } from '../api/notices-api';
import { Send, CheckCircle2, Eye, AlertCircle, Clock, Smartphone } from 'lucide-react';

interface NoticeDeliverySheetProps {
  notice: Notice | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export const NoticeDeliverySheet: React.FC<NoticeDeliverySheetProps> = ({
  notice,
  open,
  onOpenChange,
}) => {
  const { data, isLoading, error } = useQuery({
    queryKey: ['notices', 'delivery', notice?.id],
    queryFn: () => noticesApi.getNoticeDelivery(notice!.id),
    enabled: open && Boolean(notice?.id),
  });

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent className="w-full sm:max-w-xl overflow-y-auto">
        <SheetHeader className="pb-4 border-b border-border">
          <div className="flex items-center gap-2 text-primary text-xs font-semibold uppercase tracking-wider">
            <Send className="h-4 w-4" />
            <span>Delivery Ledger & Telemetry</span>
          </div>
          <SheetTitle className="text-lg font-bold">
            {notice?.title || 'Notice Delivery Details'}
          </SheetTitle>
          <SheetDescription className="text-xs">
            Push dispatch verification, recipient receipts, and read confirmations.
          </SheetDescription>
        </SheetHeader>

        {isLoading ? (
          <div className="space-y-4 py-6">
            <Skeleton className="h-20 w-full" />
            <Skeleton className="h-32 w-full" />
            <Skeleton className="h-48 w-full" />
          </div>
        ) : error ? (
          <div className="flex items-center gap-2 rounded-md bg-destructive/10 p-4 text-xs text-destructive my-6">
            <AlertCircle className="h-5 w-5 shrink-0" />
            <span>
              {error instanceof Error ? error.message : 'Failed to load delivery analytics'}
            </span>
          </div>
        ) : data ? (
          <div className="space-y-6 py-4">
            {/* Top Metrics Cards */}
            <div className="grid grid-cols-3 gap-3">
              <div className="rounded-lg border border-border bg-card p-3 shadow-xs">
                <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                  <Send className="h-3.5 w-3.5 text-blue-500" />
                  <span>Recipients</span>
                </div>
                <div className="mt-1 text-xl font-bold font-mono">{data.metrics.recipients}</div>
              </div>

              <div className="rounded-lg border border-border bg-card p-3 shadow-xs">
                <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                  <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500" />
                  <span>Delivered</span>
                </div>
                <div className="mt-1 text-xl font-bold font-mono text-emerald-600 dark:text-emerald-400">
                  {data.metrics.delivered}
                </div>
              </div>

              <div className="rounded-lg border border-border bg-card p-3 shadow-xs">
                <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                  <Eye className="h-3.5 w-3.5 text-indigo-500" />
                  <span>Read Count</span>
                </div>
                <div className="mt-1 text-xl font-bold font-mono text-indigo-600 dark:text-indigo-400">
                  {data.metrics.read}
                </div>
              </div>
            </div>

            {/* Read Rate Progress Bar */}
            <div className="rounded-lg border border-border p-4 bg-muted/20">
              <div className="flex items-center justify-between text-xs mb-2">
                <span className="font-semibold text-foreground">Read Engagement</span>
                <span className="font-mono text-muted-foreground">
                  {data.metrics.recipients > 0
                    ? Math.round((data.metrics.read / data.metrics.recipients) * 100)
                    : 0}
                  % Read
                </span>
              </div>
              <div className="h-2 w-full rounded-full bg-muted overflow-hidden">
                <div
                  className="h-full bg-primary transition-all duration-500"
                  style={{
                    width: `${
                      data.metrics.recipients > 0
                        ? Math.round((data.metrics.read / data.metrics.recipients) * 100)
                        : 0
                    }%`,
                  }}
                />
              </div>
              <div className="flex justify-between items-center text-[10px] text-muted-foreground mt-2">
                <span>{data.metrics.unread} Unread</span>
                <span>{data.metrics.failed} Push Failures</span>
              </div>
            </div>

            {/* Recipient Deliveries List */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Recipient Dispatch Log ({data.deliveries.length})
                </h4>
                <div className="flex items-center gap-1 text-[11px] text-muted-foreground">
                  <Smartphone className="h-3 w-3" />
                  <span>Push & In-App Sync</span>
                </div>
              </div>

              {data.deliveries.length === 0 ? (
                <div className="rounded-md border border-border/60 p-6 text-center text-xs text-muted-foreground">
                  No individual recipient delivery records generated yet.
                </div>
              ) : (
                <div className="space-y-2 max-h-[360px] overflow-y-auto pr-1">
                  {data.deliveries.map((d) => (
                    <div
                      key={d.id}
                      className="flex items-center justify-between rounded-md border border-border/70 bg-card p-2.5 text-xs hover:border-border transition-colors"
                    >
                      <div className="space-y-0.5">
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-[11px] font-medium text-foreground">
                            User: {d.userId.substring(0, 13)}...
                          </span>
                          <Badge
                            variant={
                              d.status === 'READ' || d.status === 'ACTIONED'
                                ? 'default'
                                : d.status === 'DELIVERED'
                                  ? 'secondary'
                                  : d.status === 'FAILED'
                                    ? 'destructive'
                                    : 'outline'
                            }
                            className="text-[10px] uppercase px-1.5 py-0"
                          >
                            {d.status}
                          </Badge>
                        </div>
                        <div className="flex items-center gap-3 text-[10px] text-muted-foreground">
                          {d.readAt ? (
                            <span>Read: {formatRelativeTime(d.readAt)}</span>
                          ) : d.deliveredAt ? (
                            <span>Delivered: {formatRelativeTime(d.deliveredAt)}</span>
                          ) : (
                            <span>Dispatched: {formatDate(d.createdAt)}</span>
                          )}
                        </div>
                      </div>

                      <div className="text-right">
                        {d.isRead ? (
                          <span className="inline-flex items-center gap-1 text-[11px] text-emerald-600 dark:text-emerald-400 font-medium">
                            <CheckCircle2 className="h-3 w-3" />
                            Confirmed
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-[11px] text-muted-foreground">
                            <Clock className="h-3 w-3" />
                            Pending Read
                          </span>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        ) : null}
      </SheetContent>
    </Sheet>
  );
};

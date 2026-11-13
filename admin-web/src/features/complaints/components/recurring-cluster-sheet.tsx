import { useQuery } from "@tanstack/react-query"
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { complaintsApi, AdminComplaint } from "../api/complaints-api"
import { formatRelativeTime } from "@/lib/utils"
import { AlertTriangle, Clock, ExternalLink, MapPin, Repeat } from "lucide-react"

interface RecurringClusterSheetProps {
  recurrenceId: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onSelectComplaint: (complaint: AdminComplaint) => void
}

export function RecurringClusterSheet({
  recurrenceId,
  open,
  onOpenChange,
  onSelectComplaint,
}: RecurringClusterSheetProps) {
  const { data, isLoading } = useQuery({
    queryKey: ["admin", "complaints", "recurring", recurrenceId],
    queryFn: () => complaintsApi.getRecurringClusterDetail(recurrenceId || ""),
    enabled: !!recurrenceId && open,
  })

  const rec = data?.recurrence
  const tickets = data?.complaints || []

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-xl flex flex-col p-0">
        <SheetHeader className="p-6 border-b border-border/70">
          <div className="flex items-center gap-2 text-primary text-xs font-semibold uppercase tracking-wider">
            <Repeat className="h-4 w-4" />
            <span>Recurring Incident Pattern</span>
          </div>
          <SheetTitle className="text-base font-semibold">
            {rec ? `${rec.category} — ${rec.location}` : "Pattern Analysis"}
          </SheetTitle>
          <SheetDescription className="text-xs">
            {rec
              ? `${rec.complaintCount} related complaints detected within ${rec.windowDays || 14}-day rolling window`
              : "Loading recurring incident cluster details..."}
          </SheetDescription>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto p-6 space-y-5">
          {isLoading ? (
            <div className="space-y-3">
              <Skeleton className="h-20 w-full" />
              <Skeleton className="h-32 w-full" />
            </div>
          ) : rec ? (
            <>
              <div className="grid grid-cols-3 gap-3 text-xs">
                <div className="rounded-xl border border-border/80 bg-card p-3">
                  <p className="text-[11px] text-muted-foreground">Escalation Tier</p>
                  <div className="mt-1 flex items-center gap-1.5 font-semibold text-foreground">
                    <AlertTriangle
                      className={`h-3.5 w-3.5 ${
                        rec.escalationLevel === "HIGH"
                          ? "text-rose-500"
                          : rec.escalationLevel === "ELEVATED"
                          ? "text-amber-500"
                          : "text-blue-500"
                      }`}
                    />
                    <span>{rec.escalationLevel || "NORMAL"}</span>
                  </div>
                </div>
                <div className="rounded-xl border border-border/80 bg-card p-3">
                  <p className="text-[11px] text-muted-foreground">Repeat Incidents</p>
                  <p className="mt-1 text-lg font-bold font-mono text-foreground">{rec.complaintCount}</p>
                </div>
                <div className="rounded-xl border border-border/80 bg-card p-3">
                  <p className="text-[11px] text-muted-foreground">Avg Resolution</p>
                  <p className="mt-1 text-lg font-bold font-mono text-foreground">
                    {rec.averageResolutionHours}h
                  </p>
                </div>
              </div>

              <div className="space-y-2.5">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Linked Complaints ({tickets.length})
                </h3>
                <div className="space-y-2">
                  {tickets.map((t) => (
                    <div
                      key={t.id}
                      onClick={() => {
                        onOpenChange(false)
                        onSelectComplaint(t)
                      }}
                      className="rounded-xl border border-border/80 bg-card p-3.5 hover:border-primary/40 cursor-pointer transition-colors space-y-1.5 text-xs"
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className="font-mono text-[11px] text-muted-foreground">
                            #{t.id.slice(0, 8)}
                          </span>
                          <span className="font-semibold text-foreground truncate">{t.title}</span>
                        </div>
                        <StatusIndicator status={t.status} label={t.status} size="sm" />
                      </div>
                      <p className="text-[11px] text-muted-foreground line-clamp-2">{t.description}</p>
                      <div className="flex items-center justify-between pt-1 text-[10px] text-muted-foreground font-mono">
                        <span className="flex items-center gap-1">
                          <MapPin className="h-3 w-3" /> {t.location}
                        </span>
                        <span className="flex items-center gap-1">
                          <Clock className="h-3 w-3" /> {formatRelativeTime(t.createdAt)}
                        </span>
                        <Button variant="ghost" size="sm" className="h-6 px-2 text-[10px] gap-1">
                          Inspect <ExternalLink className="h-2.5 w-2.5" />
                        </Button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </>
          ) : (
            <p className="text-xs text-muted-foreground text-center py-8">
              Cluster not found.
            </p>
          )}
        </div>
      </SheetContent>
    </Sheet>
  )
}

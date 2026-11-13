import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
} from "recharts"
import { PageHeader } from "@/components/ui/page-header"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import { EmptyState } from "@/components/ui/empty-state"
import { ErrorState } from "@/components/ui/error-state"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { CreateMenuDialog } from "./components/create-menu-dialog"
import { useToast } from "@/components/ui/toast"
import { messApi, MessMenuRecord } from "./api/mess-api"
import { formatDate, formatRelativeTime } from "@/lib/utils"
import {
  Utensils,
  Plus,
  Star,
  ShieldAlert,
  Archive,
  RefreshCw,
  Send,
  Coffee,
  Sun,
  Sunset,
  Moon,
  Pencil,
  MessageSquare,
  TrendingUp,
  QrCode,
  Layers,
  type LucideIcon,
} from "lucide-react"

export function MessPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [menuDialogOpen, setMenuDialogOpen] = React.useState(false)
  const [editingMenu, setEditingMenu] = React.useState<MessMenuRecord | null>(null)
  const [commentFilter, setCommentFilter] = React.useState<"ALL" | "CRITICAL" | "POSITIVE">("ALL")

  const {
    data: menus = [],
    isLoading: isMenusLoading,
    error: menusError,
    refetch: refetchMenus,
  } = useQuery({
    queryKey: ["mess", "menus"],
    queryFn: () => messApi.getAdminMenus(),
  })

  const { data: feedback, isLoading: isFeedbackLoading } = useQuery({
    queryKey: ["mess", "feedback"],
    queryFn: messApi.getFeedbackSummary,
  })

  const { data: trendsData } = useQuery({
    queryKey: ["mess", "feedback-trends"],
    queryFn: messApi.getFeedbackTrends,
  })

  const { data: categoriesData } = useQuery({
    queryKey: ["mess", "feedback-categories"],
    queryFn: messApi.getFeedbackCategories,
  })

  const commentQueryParams =
    commentFilter === "CRITICAL"
      ? { maxRating: 2, limit: 50 }
      : commentFilter === "POSITIVE"
        ? { minRating: 4, limit: 50 }
        : { limit: 50 }

  const { data: comments = [], isLoading: isCommentsLoading } = useQuery({
    queryKey: ["mess", "feedback-comments", commentFilter],
    queryFn: () => messApi.getFeedbackComments(commentQueryParams),
  })

  const { data: todayStats, refetch: refetchToday } = useQuery({
    queryKey: ["mess", "today"],
    queryFn: messApi.getTodayMealStats,
  })

  const { data: analytics } = useQuery({
    queryKey: ["mess", "entries-analytics"],
    queryFn: messApi.getEntriesAnalytics,
  })

  const publishMutation = useMutation({
    mutationFn: (id: string) => messApi.publishMenu(id),
    onSuccess: (data) => {
      toast({
        title: "Menu Published",
        description: `Daily menu for ${data.menuDate} is now visible to all students.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["mess"] })
    },
    onError: (err: Error) => {
      toast({
        title: "Publish Failed",
        description: err.message || "Failed to publish menu",
        type: "error",
      })
    },
  })

  const archiveMutation = useMutation({
    mutationFn: (id: string) => messApi.archiveMenu(id),
    onSuccess: () => {
      toast({
        title: "Menu Archived",
        description: "Menu moved to past catering archives.",
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["mess"] })
    },
    onError: (err: Error) => {
      toast({
        title: "Archive Failed",
        description: err.message || "Failed to archive menu",
        type: "error",
      })
    },
  })

  const mealIcons: Record<string, LucideIcon> = {
    BREAKFAST: Coffee,
    LUNCH: Sun,
    SNACKS: Sunset,
    DINNER: Moon,
  }

  const flaggedSignals = (categoriesData?.signals || []).filter((s) => s.flagged)
  const trends = trendsData?.trends || []
  const batchPct =
    analytics && analytics.totalEntries > 0
      ? Math.round((analytics.batchEntries / analytics.totalEntries) * 100)
      : 0
  const qrPct =
    analytics && analytics.totalEntries > 0
      ? Math.round((analytics.qrEntries / analytics.totalEntries) * 100)
      : 0

  return (
    <div className="space-y-6">
      <PageHeader
        title="Mess & Dining Operations"
        description="Daily menu authoring, meal schedule publishing, quality signals, anonymized comments, and dining turnout."
        badge={
          <StatusIndicator
            status="success"
            label={`${todayStats?.totalVerifiedToday ?? 0} Meals Served Today`}
          />
        }
        actions={
          <div className="flex items-center gap-2 flex-wrap">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                refetchMenus()
                refetchToday()
                queryClient.invalidateQueries({ queryKey: ["mess"] })
              }}
              className="text-xs gap-1.5"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh
            </Button>
            <Button
              size="sm"
              onClick={() => {
                setEditingMenu(null)
                setMenuDialogOpen(true)
              }}
              className="text-xs gap-1.5"
            >
              <Plus className="h-3.5 w-3.5" />
              Create Menu
            </Button>
          </div>
        }
      />

      {/* Dining KPI Summary */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Meals Served Today</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {todayStats?.totalVerifiedToday ?? 0}
          </p>
          <p className="text-[11px] text-muted-foreground">
            Active session: {todayStats?.activeMeal || "NONE"}
          </p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Average Rating</p>
          <div className="flex items-center gap-1.5">
            <p className="text-2xl font-bold font-mono text-foreground">
              {feedback?.averageRating ? feedback.averageRating.toFixed(1) : "—"}
            </p>
            <Star className="h-5 w-5 fill-amber-500 text-amber-500" />
          </div>
          <p className="text-[11px] text-muted-foreground">
            Across {feedback?.totalRatings ?? 0} student reviews
          </p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Verification Mode Split</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {batchPct}% / {qrPct}%
          </p>
          <p className="text-[11px] text-muted-foreground">
            Batch ({analytics?.batchEntries ?? 0}) vs QR ({analytics?.qrEntries ?? 0})
          </p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Quality Alerts</p>
          <p className="text-2xl font-bold font-mono text-rose-600 dark:text-rose-400">
            {flaggedSignals.length}
          </p>
          <p className="text-[11px] text-muted-foreground">
            {feedback?.totalComments ?? 0} anonymized written comments
          </p>
        </div>
      </div>

      {/* Negative Quality Signal Banner */}
      {flaggedSignals.length > 0 && (
        <div className="rounded-xl border border-rose-500/30 bg-rose-500/5 p-4 space-y-2">
          <div className="flex items-center gap-2 text-rose-600 dark:text-rose-400 text-xs font-semibold">
            <ShieldAlert className="h-4 w-4" />
            Dining Quality Signal Alert ({flaggedSignals.length} flagged categories)
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
            {flaggedSignals.map((sig) => (
              <div
                key={sig.category}
                className="rounded-lg bg-card border border-rose-500/20 px-3 py-2 flex items-center justify-between gap-2 text-xs"
              >
                <div>
                  <span className="font-semibold text-foreground">{sig.category}</span>
                  <p className="text-[11px] text-muted-foreground">
                    {sig.flagReason || `${sig.negativePercentage}% negative ratings`}
                  </p>
                </div>
                <Badge variant="destructive" className="font-mono text-[10px] shrink-0">
                  {sig.averageRating.toFixed(1)}★
                </Badge>
              </div>
            ))}
          </div>
        </div>
      )}

      <Tabs defaultValue="menus" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="menus" className="text-xs gap-1.5">
            <Utensils className="h-3.5 w-3.5" />
            Daily Menus ({menus.length})
          </TabsTrigger>
          <TabsTrigger value="feedback" className="text-xs gap-1.5">
            <TrendingUp className="h-3.5 w-3.5" />
            Quality Trends & Categories
          </TabsTrigger>
          <TabsTrigger value="comments" className="text-xs gap-1.5">
            <MessageSquare className="h-3.5 w-3.5" />
            Student Comments ({comments.length})
          </TabsTrigger>
          <TabsTrigger value="turnout" className="text-xs gap-1.5">
            <QrCode className="h-3.5 w-3.5" />
            Turnout & Verification
          </TabsTrigger>
        </TabsList>

        {/* Daily Menus Tab */}
        <TabsContent value="menus" className="space-y-4">
          {isMenusLoading ? (
            <div className="space-y-3">
              <Skeleton className="h-36 w-full" />
              <Skeleton className="h-36 w-full" />
            </div>
          ) : menusError ? (
            <ErrorState
              status={(menusError as { status?: number })?.status}
              message={(menusError as Error)?.message}
              onRetry={refetchMenus}
            />
          ) : menus.length > 0 ? (
            <div className="space-y-4">
              {menus.map((menu) => (
                <div
                  key={menu.id}
                  className="rounded-xl border border-border/80 bg-card p-5 shadow-sm space-y-4"
                >
                  <div className="flex items-center justify-between border-b border-border/60 pb-3 flex-wrap gap-2">
                    <div className="flex items-center gap-3">
                      <h3 className="text-sm font-bold font-mono text-foreground">
                        {formatDate(menu.menuDate)}
                      </h3>
                      <Badge
                        variant={
                          menu.status === "PUBLISHED"
                            ? "success"
                            : menu.status === "DRAFT"
                              ? "warning"
                              : "secondary"
                        }
                        className="text-[10px]"
                      >
                        {menu.status}
                      </Badge>
                    </div>

                    <div className="flex items-center gap-2">
                      {menu.status !== "ARCHIVED" && (
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-7 text-xs gap-1"
                          onClick={() => {
                            setEditingMenu(menu)
                            setMenuDialogOpen(true)
                          }}
                        >
                          <Pencil className="h-3 w-3" />
                          Edit Meals
                        </Button>
                      )}
                      {menu.status === "DRAFT" && (
                        <Button
                          size="sm"
                          className="h-7 text-xs gap-1"
                          loading={publishMutation.isPending && publishMutation.variables === menu.id}
                          onClick={() => publishMutation.mutate(menu.id)}
                        >
                          <Send className="h-3 w-3" />
                          Publish Menu
                        </Button>
                      )}
                      {menu.status !== "ARCHIVED" && (
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-7 text-xs gap-1"
                          loading={archiveMutation.isPending && archiveMutation.variables === menu.id}
                          onClick={() => archiveMutation.mutate(menu.id)}
                        >
                          <Archive className="h-3 w-3" />
                          Archive
                        </Button>
                      )}
                    </div>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-3">
                    {menu.meals?.map((meal, idx) => {
                      const Icon = mealIcons[meal.mealType] || Utensils
                      return (
                        <div
                          key={meal.id || idx}
                          className="rounded-lg border border-border/60 bg-muted/20 p-3 space-y-2"
                        >
                          <div className="flex items-center justify-between">
                            <span className="flex items-center gap-1.5 text-xs font-semibold text-foreground">
                              <Icon className="h-3.5 w-3.5 text-primary" />
                              {meal.mealType}
                            </span>
                            <span className="text-[10px] font-mono text-muted-foreground">
                              {meal.availability}
                            </span>
                          </div>
                          <div className="flex flex-wrap gap-1">
                            {meal.items?.map((item, i) => (
                              <span
                                key={i}
                                className="inline-flex items-center rounded bg-background px-1.5 py-0.5 text-[11px] font-medium border border-border/50 text-foreground"
                              >
                                {item}
                              </span>
                            ))}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={Utensils}
              title="No Mess Menus Authored"
              description="Create daily breakfast, lunch, snacks, and dinner schedules for institutional residents."
              actionLabel="Create First Menu"
              onAction={() => {
                setEditingMenu(null)
                setMenuDialogOpen(true)
              }}
            />
          )}
        </TabsContent>

        {/* Feedback Trends & Categories Tab */}
        <TabsContent value="feedback" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            <div className="rounded-xl border border-border/80 bg-card p-5 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-semibold text-foreground">Daily Satisfaction Trend</h3>
                <span className="text-[11px] text-muted-foreground font-mono">Average Star Rating</span>
              </div>
              {trends.length > 0 ? (
                <div className="h-60 w-full">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={trends}>
                      <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" opacity={0.4} />
                      <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                      <YAxis domain={[0, 5]} tick={{ fontSize: 11 }} />
                      <Tooltip />
                      <Area
                        type="monotone"
                        dataKey="averageRating"
                        name="Avg Rating"
                        stroke="hsl(var(--primary))"
                        fill="hsl(var(--primary))"
                        fillOpacity={0.18}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <p className="text-xs text-muted-foreground py-8 text-center">
                  No dated trend data available yet.
                </p>
              )}
            </div>

            <div className="rounded-xl border border-border/80 bg-card p-5 space-y-3">
              <h3 className="text-sm font-semibold text-foreground">Category Breakdown</h3>
              {isFeedbackLoading ? (
                <Skeleton className="h-44 w-full" />
              ) : (categoriesData?.categories?.length ?? 0) > 0 ? (
                <div className="space-y-2.5">
                  {categoriesData!.categories.map((cat) => (
                    <div
                      key={cat.category}
                      className="rounded-lg border border-border/60 bg-muted/20 p-3 flex items-center justify-between"
                    >
                      <div>
                        <p className="text-xs font-semibold text-foreground">{cat.category}</p>
                        <p className="text-[11px] text-muted-foreground">
                          {cat.feedbackCount} ratings • {cat.negativePercentage}% negative
                        </p>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge
                          variant={cat.averageRating >= 3.5 ? "success" : cat.averageRating >= 2.5 ? "warning" : "destructive"}
                          className="font-mono text-[10px]"
                        >
                          {cat.averageRating.toFixed(1)}★
                        </Badge>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-xs text-muted-foreground py-8 text-center">
                  No category feedback logged yet.
                </p>
              )}
            </div>
          </div>

          <div className="rounded-xl border border-border/80 bg-card p-5 space-y-4">
            <h3 className="text-sm font-semibold text-foreground">Rating Distribution by Tier & Meal</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="space-y-2">
                {Object.entries(feedback?.ratingDistribution || { "5": 0, "4": 0, "3": 0, "2": 0, "1": 0 })
                  .sort((a, b) => Number(b[0]) - Number(a[0]))
                  .map(([stars, count]) => {
                    const total = feedback?.totalRatings || 1
                    const pct = Math.round(((count || 0) / total) * 100)
                    return (
                      <div key={stars} className="flex items-center gap-3 text-xs">
                        <span className="w-8 font-mono font-bold text-foreground">{stars}★</span>
                        <div className="flex-1 h-2 bg-muted rounded-full overflow-hidden">
                          <div
                            className="h-full bg-amber-500 rounded-full transition-all"
                            style={{ width: `${pct}%` }}
                          />
                        </div>
                        <span className="w-12 text-right font-mono text-muted-foreground">
                          {count} ({pct}%)
                        </span>
                      </div>
                    )
                  })}
              </div>

              <div className="grid grid-cols-2 gap-2.5">
                {Object.entries(feedback?.mealBreakdown || {}).map(([meal, data]) => (
                  <div key={meal} className="rounded-lg border border-border/60 bg-muted/20 p-3 space-y-1">
                    <p className="text-xs font-semibold text-foreground">{meal}</p>
                    <p className="text-lg font-bold font-mono text-foreground">
                      {data.averageRating.toFixed(1)}★
                    </p>
                    <p className="text-[11px] text-muted-foreground">{data.count} ratings</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </TabsContent>

        {/* Anonymized Comments Tab */}
        <TabsContent value="comments" className="space-y-4">
          <div className="flex items-center justify-between gap-3 flex-wrap">
            <p className="text-xs text-muted-foreground">
              Student identities are anonymized by the backend privacy model.
            </p>
            <Select value={commentFilter} onValueChange={(v: "ALL" | "CRITICAL" | "POSITIVE") => setCommentFilter(v)}>
              <SelectTrigger className="w-[180px] h-8 text-xs">
                <SelectValue placeholder="Filter rating..." />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="ALL">All Comments</SelectItem>
                <SelectItem value="CRITICAL">Critical (1-2★)</SelectItem>
                <SelectItem value="POSITIVE">Positive (4-5★)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {isCommentsLoading ? (
            <Skeleton className="h-44 w-full" />
          ) : comments.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {comments.map((c) => (
                <div
                  key={c.id}
                  className="rounded-xl border border-border/80 bg-card p-4 space-y-2"
                >
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <Badge
                        variant={c.rating >= 4 ? "success" : c.rating <= 2 ? "destructive" : "warning"}
                        className="font-mono text-[10px]"
                      >
                        {c.rating}★
                      </Badge>
                      <Badge variant="outline" className="text-[10px]">
                        {c.category}
                      </Badge>
                      {c.mealType && (
                        <span className="text-[10px] font-mono text-muted-foreground">{c.mealType}</span>
                      )}
                    </div>
                    <span className="text-[10px] font-mono text-muted-foreground">
                      {formatRelativeTime(c.createdAt)}
                    </span>
                  </div>
                  <p className="text-xs text-foreground leading-relaxed">{c.comment}</p>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState
              icon={MessageSquare}
              title="No Written Feedback"
              description="No written comments matched the selected rating filter."
            />
          )}
        </TabsContent>

        {/* Turnout & Verification Tab */}
        <TabsContent value="turnout" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
            {(["BREAKFAST", "LUNCH", "SNACKS", "DINNER"] as const).map((mealType) => {
              const Icon = mealIcons[mealType] || Utensils
              const stat = todayStats?.counts?.[mealType] || { total: 0, batch: 0, qr: 0 }
              return (
                <div key={mealType} className="rounded-xl border border-border/80 bg-card p-4 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-foreground">{mealType}</span>
                    <Icon className="h-4 w-4 text-primary" />
                  </div>
                  <p className="text-2xl font-bold font-mono text-foreground">{stat.total}</p>
                  <p className="text-[11px] text-muted-foreground font-mono">
                    Batch: {stat.batch} • QR: {stat.qr}
                  </p>
                </div>
              )
            })}
          </div>

          <div className="rounded-xl border border-border/80 bg-card p-5 space-y-3">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-foreground">All-Time Meal Entry Totals</h3>
              <Layers className="h-4 w-4 text-muted-foreground" />
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
              {Object.entries(analytics?.mealBreakdown || {}).map(([meal, count]) => (
                <div key={meal} className="rounded-lg border border-border/60 bg-muted/20 p-3">
                  <p className="text-muted-foreground font-medium">{meal}</p>
                  <p className="text-xl font-bold font-mono text-foreground">{count}</p>
                </div>
              ))}
            </div>
          </div>
        </TabsContent>
      </Tabs>

      <CreateMenuDialog
        open={menuDialogOpen}
        onOpenChange={(open) => {
          setMenuDialogOpen(open)
          if (!open) setEditingMenu(null)
        }}
        menuToEdit={editingMenu}
      />
    </div>
  )
}

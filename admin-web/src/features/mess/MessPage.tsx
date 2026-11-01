import * as React from "react"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { PageHeader } from "@/components/ui/page-header"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { CreateMenuDialog } from "./components/create-menu-dialog"
import { useToast } from "@/components/ui/toast"
import { messApi, MessMenuRecord } from "./api/mess-api"
import { formatDate } from "@/lib/utils"
import {
  Utensils,
  Plus,
  Star,
  ShieldAlert,
  Clock,
  CheckCircle2,
  Archive,
  RefreshCw,
  Send,
  Coffee,
  Sun,
  Sunset,
  Moon,
} from "lucide-react"

export function MessPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [createMenuOpen, setCreateMenuOpen] = React.useState(false)

  const { data: menus = [], isLoading: isMenusLoading, refetch: refetchMenus } = useQuery({
    queryKey: ["mess", "menus"],
    queryFn: () => messApi.getAdminMenus(),
  })

  const { data: feedback, isLoading: isFeedbackLoading } = useQuery({
    queryKey: ["mess", "feedback"],
    queryFn: messApi.getFeedbackSummary,
  })

  const { data: todayStats } = useQuery({
    queryKey: ["mess", "today"],
    queryFn: messApi.getTodayMealStats,
  })

  const publishMutation = useMutation({
    mutationFn: (id: string) => messApi.publishMenu(id),
    onSuccess: (data) => {
      toast({
        title: "Menu Published",
        description: `Daily menu for ${data.menu_date} is now visible to all students.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["mess"] })
    },
    onError: (err: any) => {
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
  })

  const mealIcons: Record<string, any> = {
    BREAKFAST: Coffee,
    LUNCH: Sun,
    SNACKS: Sunset,
    DINNER: Moon,
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title="Mess & Dining Operations"
        description="Daily menu authoring, meal schedule publishing, student quality feedback, and dining turnout telemetry."
        badge={
          <StatusIndicator
            status="success"
            label={`${todayStats?.totalEntries ?? 0} Meals Served Today`}
          />
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => refetchMenus()}
              className="text-xs gap-1.5"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh
            </Button>
            <Button size="sm" onClick={() => setCreateMenuOpen(true)} className="gap-1.5 text-xs">
              <Plus className="h-3.5 w-3.5" />
              Author Daily Menu
            </Button>
          </div>
        }
      />

      {/* Operational Highlights */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Today's Total Check-ins</p>
          <p className="text-2xl font-bold font-mono text-foreground">{todayStats?.totalEntries ?? 0}</p>
          <p className="text-[11px] text-muted-foreground">Verified student dining entries</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Average Student Rating</p>
          <div className="flex items-baseline gap-2">
            <p className="text-2xl font-bold font-mono text-foreground">
              {feedback?.averageRating ? feedback.averageRating.toFixed(1) : "—"}
            </p>
            <span className="text-xs text-muted-foreground">/ 5.0</span>
          </div>
          <p className="text-[11px] text-muted-foreground">{feedback?.totalRatings ?? 0} total ratings logged</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Published Menus</p>
          <p className="text-2xl font-bold font-mono text-foreground">
            {menus.filter((m) => m.status === "PUBLISHED").length}
          </p>
          <p className="text-[11px] text-muted-foreground">In active dining circulation</p>
        </div>

        <div className="rounded-xl border border-border/80 bg-card p-4 space-y-1">
          <p className="text-xs text-muted-foreground font-medium">Student Comments</p>
          <p className="text-2xl font-bold font-mono text-foreground">{feedback?.totalComments ?? 0}</p>
          <p className="text-[11px] text-muted-foreground">Qualitative feedback notes</p>
        </div>
      </div>

      <Tabs defaultValue="menus" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="menus" className="text-xs gap-1.5">
            <Utensils className="h-3.5 w-3.5" />
            Daily Menus ({menus.length})
          </TabsTrigger>
          <TabsTrigger value="feedback" className="text-xs gap-1.5">
            <Star className="h-3.5 w-3.5" />
            Quality & Feedback Analytics
          </TabsTrigger>
          <TabsTrigger value="security" className="text-xs gap-1.5">
            <ShieldAlert className="h-3.5 w-3.5" />
            Verification Security Architecture
          </TabsTrigger>
        </TabsList>

        {/* MENUS TAB */}
        <TabsContent value="menus" className="space-y-4">
          {isMenusLoading ? (
            <div className="space-y-3">
              {Array.from({ length: 3 }).map((_, i) => (
                <div key={i} className="h-28 rounded-xl bg-muted/40 animate-pulse" />
              ))}
            </div>
          ) : menus.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {menus.map((menu) => (
                <div
                  key={menu.id}
                  className="rounded-xl border border-border/80 bg-card p-5 space-y-4 shadow-sm hover:border-border transition-colors"
                >
                  <div className="flex items-start justify-between">
                    <div>
                      <div className="flex items-center gap-2">
                        <h3 className="text-sm font-semibold text-foreground">
                          {menu.menu_date}
                        </h3>
                        <Badge
                          variant={
                            menu.status === "PUBLISHED"
                              ? "success"
                              : menu.status === "ARCHIVED"
                              ? "secondary"
                              : "warning"
                          }
                          className="text-[10px]"
                        >
                          {menu.status}
                        </Badge>
                      </div>
                      <p className="text-[11px] text-muted-foreground font-mono">
                        Authoring ID: #{menu.id.slice(0, 8)}
                      </p>
                    </div>

                    <div className="flex items-center gap-1.5">
                      {menu.status === "DRAFT" && (
                        <Button
                          size="sm"
                          onClick={() => publishMutation.mutate(menu.id)}
                          loading={publishMutation.isPending}
                          className="h-7 text-xs gap-1"
                        >
                          <Send className="h-3 w-3" /> Publish
                        </Button>
                      )}
                      {menu.status === "PUBLISHED" && (
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => archiveMutation.mutate(menu.id)}
                          loading={archiveMutation.isPending}
                          className="h-7 text-xs gap-1"
                        >
                          <Archive className="h-3 w-3" /> Archive
                        </Button>
                      )}
                    </div>
                  </div>

                  {/* Meals grid */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    {menu.meals?.map((m) => {
                      const Icon = mealIcons[m.meal_type] || Utensils
                      return (
                        <div key={m.meal_type} className="rounded-lg bg-muted/30 p-2.5 space-y-1">
                          <div className="flex items-center gap-1.5 font-semibold text-foreground text-[11px]">
                            <Icon className="h-3.5 w-3.5 text-muted-foreground" />
                            {m.meal_type}
                          </div>
                          <p className="text-[11px] text-muted-foreground line-clamp-2">
                            {Array.isArray(m.items) ? m.items.join(", ") : String(m.items || "—")}
                          </p>
                        </div>
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="rounded-xl border border-dashed border-border/80 bg-card p-12 text-center text-xs text-muted-foreground space-y-3">
              <Utensils className="h-8 w-8 mx-auto opacity-40" />
              <p>No mess menus configured in the system.</p>
              <Button size="sm" onClick={() => setCreateMenuOpen(true)}>
                Author First Daily Menu
              </Button>
            </div>
          )}
        </TabsContent>

        {/* FEEDBACK ANALYTICS TAB */}
        <TabsContent value="feedback" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Rating distribution breakdown */}
            <div className="rounded-xl border border-border/80 bg-card p-5 space-y-4 shadow-sm">
              <h2 className="text-sm font-semibold text-foreground">Rating Distribution (1 to 5 Stars)</h2>
              <div className="space-y-2">
                {[5, 4, 3, 2, 1].map((stars) => {
                  const dist = feedback?.ratingDistribution as Record<string, number> | undefined
                  const count = dist?.[String(stars)] || 0
                  const total = feedback?.totalRatings || 1
                  const pct = Math.round((count / total) * 100)
                  return (
                    <div key={stars} className="flex items-center gap-3 text-xs">
                      <span className="w-12 font-mono text-muted-foreground flex items-center gap-1">
                        {stars} <Star className="h-3 w-3 fill-amber-400 text-amber-400" />
                      </span>
                      <div className="h-2 flex-1 rounded-full bg-muted/60 overflow-hidden">
                        <div
                          className="h-full bg-amber-500 rounded-full transition-all"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                      <span className="w-10 text-right font-mono text-muted-foreground">{count}</span>
                    </div>
                  )
                })}
              </div>
            </div>

            {/* Meal-wise average ratings */}
            <div className="rounded-xl border border-border/80 bg-card p-5 space-y-4 shadow-sm">
              <h2 className="text-sm font-semibold text-foreground">Meal-wise Quality Rating</h2>
              <div className="space-y-3">
                {feedback?.mealBreakdown &&
                  Object.entries(feedback.mealBreakdown).map(([meal, data]) => (
                    <div
                      key={meal}
                      className="p-3 rounded-lg border border-border/60 bg-muted/20 flex items-center justify-between text-xs"
                    >
                      <span className="font-semibold text-foreground">{meal}</span>
                      <div className="flex items-center gap-3">
                        <span className="text-[11px] text-muted-foreground">{data.count} reviews</span>
                        <Badge variant="outline" className="font-mono text-xs">
                          ★ {data.averageRating.toFixed(2)}
                        </Badge>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          </div>
        </TabsContent>

        {/* SECURITY ARCHITECTURE EXPLANATION TAB */}
        <TabsContent value="security" className="space-y-4">
          <div className="rounded-xl border border-border/80 bg-card p-6 space-y-4 shadow-sm">
            <div className="flex items-center gap-2 text-foreground font-semibold text-sm">
              <ShieldAlert className="h-5 w-5 text-primary" />
              Cryptographic Meal Verification Contract
            </div>

            <p className="text-xs text-muted-foreground leading-relaxed">
              In accordance with institutional security guidelines, the CampusOS Control Plane enforces strict presentation-verified meal verification. Unauthenticated student ID submissions are prohibited from granting meal entitlements.
            </p>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 pt-2 text-xs">
              <div className="p-3.5 rounded-lg bg-muted/30 border border-border/60 space-y-1">
                <span className="font-semibold text-foreground">Identity Presentation</span>
                <p className="text-[11px] text-muted-foreground leading-relaxed">
                  Students present their signed Ed25519 CampusOS Passport presentation token via dynamic QR or BLE beacon.
                </p>
              </div>

              <div className="p-3.5 rounded-lg bg-muted/30 border border-border/60 space-y-1">
                <span className="font-semibold text-foreground">Anti-Replay / Nonce</span>
                <p className="text-[11px] text-muted-foreground leading-relaxed">
                  Each dining entry requires a unique challenge nonce and timestamp within an active meal window to prevent double-swiping.
                </p>
              </div>

              <div className="p-3.5 rounded-lg bg-muted/30 border border-border/60 space-y-1">
                <span className="font-semibold text-foreground">Audited Enrollment</span>
                <p className="text-[11px] text-muted-foreground leading-relaxed">
                  Only institutionally authenticated Mess Staff credentials can validate and record official dining meal entries.
                </p>
              </div>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      <CreateMenuDialog open={createMenuOpen} onOpenChange={setCreateMenuOpen} />
    </div>
  )
}

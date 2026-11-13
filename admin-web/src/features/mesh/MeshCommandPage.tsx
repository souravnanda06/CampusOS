import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import {
  Radio,
  AlertTriangle,
  ShieldAlert,
  Send,
  Plus,
  RefreshCw,
  CheckCircle2,
  EyeOff,
  KeyRound,
  Hash,
  UserX,
  UserCheck,
  Flag,
  ShieldCheck,
  Users,
} from "lucide-react"
import { PageHeader } from "@/components/ui/page-header"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { StatusIndicator } from "@/components/ui/status-indicator"
import { EmptyState } from "@/components/ui/empty-state"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"
import { useToast } from "@/components/ui/toast"
import { formatDate } from "@/lib/utils"
import {
  meshApi,
  MeshAccountAction,
  MeshFlagAction,
  MeshFlaggedAccountItem,
  MeshMessageItem,
  MeshModerationFlagItem,
} from "./api/mesh-api"

type PendingDialogAction =
  | {
      kind: "flag"
      flag: MeshModerationFlagItem
      action: MeshFlagAction
      title: string
      description: string
      defaultReason: string
      destructive?: boolean
    }
  | {
      kind: "channel"
      channelId: string
      action: "RESTRICT" | "RESTORE"
      title: string
      description: string
      defaultReason: string
      destructive?: boolean
    }
  | {
      kind: "account"
      account: MeshFlaggedAccountItem
      action: MeshAccountAction
      title: string
      description: string
      defaultReason: string
      destructive?: boolean
    }
  | {
      kind: "message"
      message: MeshMessageItem
      title: string
      description: string
      defaultReason: string
      destructive?: boolean
    }

export function MeshCommandPage() {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [selectedChannel, setSelectedChannel] = React.useState<string>("channel:emergency")
  const [broadcastText, setBroadcastText] = React.useState("")
  const [newChannelOpen, setNewChannelOpen] = React.useState(false)
  const [channelName, setChannelName] = React.useState("")
  const [channelDesc, setChannelDesc] = React.useState("")
  const [flagFilter, setFlagFilter] = React.useState<string>("ALL")
  const [accountFilter, setAccountFilter] = React.useState<string>("ALL")

  const [pendingAction, setPendingAction] = React.useState<PendingDialogAction | null>(null)
  const [actionNotes, setActionNotes] = React.useState("")

  const openActionDialog = (cfg: PendingDialogAction) => {
    setActionNotes(cfg.defaultReason)
    setPendingAction(cfg)
  }

  const { data: health } = useQuery({
    queryKey: ["mesh", "health"],
    queryFn: meshApi.getHealth,
    refetchInterval: 15000,
  })

  const { data: channels = [] } = useQuery({
    queryKey: ["mesh", "channels"],
    queryFn: meshApi.getChannels,
  })

  const {
    data: messages = [],
    isLoading: isMsgsLoading,
    refetch: refetchMsgs,
  } = useQuery({
    queryKey: ["mesh", "messages", selectedChannel],
    queryFn: () => meshApi.getChannelMessages(selectedChannel, 100),
    refetchInterval: 8000,
  })

  const {
    data: flags = [],
    isLoading: isFlagsLoading,
    refetch: refetchFlags,
  } = useQuery({
    queryKey: ["mesh", "flags", flagFilter],
    queryFn: () => meshApi.getModerationFlags(flagFilter),
    refetchInterval: 12000,
  })

  const {
    data: flaggedAccounts = [],
    isLoading: isAccountsLoading,
    refetch: refetchAccounts,
  } = useQuery({
    queryKey: ["mesh", "accounts"],
    queryFn: meshApi.getFlaggedAccounts,
    refetchInterval: 15000,
  })

  const broadcastMutation = useMutation({
    mutationFn: () => meshApi.broadcastMessage(selectedChannel, broadcastText.trim()),
    onSuccess: (res) => {
      if (res.rejected && res.rejected.length > 0) {
        toast({
          title: "Broadcast Rejected",
          description: res.rejected[0].reason,
          type: "error",
        })
        return
      }
      toast({
        title: selectedChannel === "channel:emergency" ? "Emergency Flare Dispatched" : "Mesh Message Synced",
        description: `Published to ${selectedChannel} for mesh & offline relay.`,
        type: "success",
      })
      setBroadcastText("")
      queryClient.invalidateQueries({ queryKey: ["mesh", "messages", selectedChannel] })
      queryClient.invalidateQueries({ queryKey: ["mesh", "health"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Broadcast Failed",
        description: err instanceof Error ? err.message : "Failed to publish mesh message",
        type: "error",
      })
    },
  })

  const createChannelMutation = useMutation({
    mutationFn: () => meshApi.createChannel(channelName, channelDesc),
    onSuccess: (res) => {
      toast({
        title: "Channel Created",
        description: `${res.channel.name} is now active on the Campus Mesh.`,
        type: "success",
      })
      setNewChannelOpen(false)
      setChannelName("")
      setChannelDesc("")
      setSelectedChannel(res.channel.channelId)
      queryClient.invalidateQueries({ queryKey: ["mesh", "channels"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Creation Failed",
        description: err instanceof Error ? err.message : "Could not create channel",
        type: "error",
      })
    },
  })

  const resolveFlagMutation = useMutation({
    mutationFn: (vars: { flagId: string; action: MeshFlagAction; notes: string }) =>
      meshApi.resolveModerationFlag(vars.flagId, vars.action, vars.notes),
    onSuccess: (_res, vars) => {
      toast({
        title: "Moderation Action Applied",
        description: `Action ${vars.action} saved and enforced.`,
        type: "success",
      })
      setPendingAction(null)
      queryClient.invalidateQueries({ queryKey: ["mesh"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Moderation Failed",
        description: err instanceof Error ? err.message : "Could not resolve flag",
        type: "error",
      })
    },
  })

  const accountControlMutation = useMutation({
    mutationFn: (vars: { userId: string; action: MeshAccountAction; reason: string }) =>
      meshApi.controlFlaggedAccount(vars.userId, vars.action, vars.reason),
    onSuccess: (_res, vars) => {
      toast({
        title: "Account Status Updated",
        description: `Account action ${vars.action} applied.`,
        type: "success",
      })
      setPendingAction(null)
      queryClient.invalidateQueries({ queryKey: ["mesh"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Account Update Failed",
        description: err instanceof Error ? err.message : "Could not update account status",
        type: "error",
      })
    },
  })

  const channelRestrictMutation = useMutation({
    mutationFn: (vars: { channelId: string; action: "RESTRICT" | "RESTORE"; reason: string }) =>
      meshApi.restrictChannel(vars.channelId, vars.action, vars.reason),
    onSuccess: (_res, vars) => {
      toast({
        title: vars.action === "RESTORE" ? "Channel Restored" : "Channel Dismantled & Restricted",
        description:
          vars.action === "RESTORE"
            ? "Channel is now unlocked for campus messaging."
            : "Channel messaging has been disabled.",
        type: "success",
      })
      setPendingAction(null)
      queryClient.invalidateQueries({ queryKey: ["mesh"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Channel Action Failed",
        description: err instanceof Error ? err.message : "Could not update channel status",
        type: "error",
      })
    },
  })

  const moderateMsgMutation = useMutation({
    mutationFn: (vars: { messageId: string; reason: string }) =>
      meshApi.moderateMessage(vars.messageId, {
        category: "HARASSMENT",
        severity: "HIGH",
        reason: vars.reason,
        hideMessage: true,
      }),
    onSuccess: () => {
      toast({
        title: "Message Flagged & Hidden",
        description: "The message was hidden from channels and added to the moderation log.",
        type: "success",
      })
      setPendingAction(null)
      queryClient.invalidateQueries({ queryKey: ["mesh"] })
    },
    onError: (err: unknown) => {
      toast({
        title: "Moderation Failed",
        description: err instanceof Error ? err.message : "Could not moderate message",
        type: "error",
      })
    },
  })

  const handleConfirmPendingAction = () => {
    if (!pendingAction) return
    const trimmedNotes = actionNotes.trim() || pendingAction.defaultReason
    if (pendingAction.kind === "flag") {
      resolveFlagMutation.mutate({
        flagId: pendingAction.flag.flagId,
        action: pendingAction.action,
        notes: trimmedNotes,
      })
    } else if (pendingAction.kind === "account") {
      if (!pendingAction.account.userId) return
      accountControlMutation.mutate({
        userId: pendingAction.account.userId,
        action: pendingAction.action,
        reason: trimmedNotes,
      })
    } else if (pendingAction.kind === "channel") {
      channelRestrictMutation.mutate({
        channelId: pendingAction.channelId,
        action: pendingAction.action,
        reason: trimmedNotes,
      })
    } else {
      moderateMsgMutation.mutate({
        messageId: pendingAction.message.messageId,
        reason: trimmedNotes,
      })
    }
  }

  const isActionPending =
    resolveFlagMutation.isPending ||
    accountControlMutation.isPending ||
    channelRestrictMutation.isPending ||
    moderateMsgMutation.isPending

  const openFlagsCount = flags.filter((f) => f.status === "OPEN" || f.status === "ESCALATED").length
  const restrictedAccountsCount = flaggedAccounts.filter((a) => a.accountStatus !== "ACTIVE").length

  const visibleAccounts = React.useMemo(() => {
    if (accountFilter === "ALL") return flaggedAccounts
    if (accountFilter === "RESTRICTED") {
      return flaggedAccounts.filter((a) => a.accountStatus !== "ACTIVE")
    }
    return flaggedAccounts.filter((a) => a.accountStatus === accountFilter)
  }, [flaggedAccounts, accountFilter])

  return (
    <div className="space-y-6">
      <PageHeader
        title="Campus Mesh & Moderation Control"
        description="Monitor live mesh channels, inspect why accounts were flagged, and restrict or restore Mesh Chat access."
        badge={
          <StatusIndicator
            status={health?.connected ? "success" : "warning"}
            label={health?.connected ? `Mesh Sync Online (${health.messageCount} msgs)` : "Connecting"}
            pulse={!!health?.connected}
          />
        }
        actions={
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => {
                refetchMsgs()
                refetchFlags()
                refetchAccounts()
              }}
              className="text-xs gap-1.5"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              Refresh
            </Button>
            <Button size="sm" onClick={() => setNewChannelOpen(true)} className="text-xs gap-1.5">
              <Plus className="h-3.5 w-3.5" />
              New Channel
            </Button>
          </div>
        }
      />

      <Tabs defaultValue="moderation" className="space-y-4">
        <TabsList className="bg-muted/60">
          <TabsTrigger value="moderation" className="text-xs gap-1.5">
            <ShieldAlert className="h-3.5 w-3.5 text-rose-500" />
            Moderation Queue ({openFlagsCount})
          </TabsTrigger>
          <TabsTrigger value="accounts" className="text-xs gap-1.5">
            <Users className="h-3.5 w-3.5 text-amber-500" />
            Flagged Accounts ({flaggedAccounts.length}
            {restrictedAccountsCount > 0 ? ` · ${restrictedAccountsCount} restricted` : ""})
          </TabsTrigger>
          <TabsTrigger value="channels" className="text-xs gap-1.5">
            <Radio className="h-3.5 w-3.5" />
            Channels &amp; Emergency Flare
          </TabsTrigger>
        </TabsList>

        {/* TAB 1: MODERATION QUEUE */}
        <TabsContent value="moderation" className="space-y-4">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-2 flex-wrap">
              {(["ALL", "OPEN", "ESCALATED", "HIDDEN", "DISMISSED"] as const).map((st) => (
                <Button
                  key={st}
                  size="sm"
                  variant={flagFilter === st ? "default" : "outline"}
                  onClick={() => setFlagFilter(st)}
                  className="h-7 text-xs"
                >
                  {st}
                </Button>
              ))}
            </div>
            <span className="text-xs font-mono text-muted-foreground">{flags.length} flag(s)</span>
          </div>

          {isFlagsLoading ? (
            <Skeleton className="h-32 w-full" />
          ) : flags.length === 0 ? (
            <EmptyState
              icon={CheckCircle2}
              title="No Moderation Flags"
              description="All Campus Mesh channels are clean with no pending moderation alerts."
            />
          ) : (
            <div className="space-y-3">
              {flags.map((flag) => {
                const acct = flag.reportedUser
                const isRestricted = acct?.accountStatus === "RESTRICTED" || acct?.accountStatus === "REVOKED"

                return (
                  <div
                    key={flag.flagId}
                    className="rounded-xl border border-border/80 bg-card p-4 flex flex-col lg:flex-row lg:items-start justify-between gap-4 text-xs"
                  >
                    <div className="space-y-2 flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <Badge
                          variant={flag.severity === "CRITICAL" ? "destructive" : "warning"}
                          className="text-[10px] font-mono"
                        >
                          {flag.severity} • {flag.category}
                        </Badge>
                        <Badge variant="outline" className="text-[10px] font-mono">
                          {flag.status}
                        </Badge>
                        {acct && (
                          <Badge
                            variant={
                              acct.accountStatus === "REVOKED"
                                ? "destructive"
                                : acct.accountStatus === "RESTRICTED"
                                ? "warning"
                                : "success"
                            }
                            className="text-[10px] font-mono"
                          >
                            Account: {acct.accountStatus}
                          </Badge>
                        )}
                        {flag.signatureVerified && (
                          <Badge variant="success" className="text-[10px] font-mono">
                            Ed25519 Signed
                          </Badge>
                        )}
                        <span className="font-mono text-[11px] text-muted-foreground">
                          {flag.channelId} • {flag.source}
                        </span>
                      </div>

                      {/* Why Flagged Breakdown */}
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-semibold text-foreground">Why flagged:</span>
                        {(flag.matchedPatterns?.length ? flag.matchedPatterns : [flag.category]).map((reason) => (
                          <Badge key={reason} variant="secondary" className="text-[10px] font-medium">
                            {reason}
                          </Badge>
                        ))}
                      </div>

                      <p className="text-foreground bg-muted/30 rounded-lg p-2.5 border border-border/50">
                        &ldquo;{flag.messageSnapshot || "No snapshot"}&rdquo;
                      </p>

                      <div className="flex flex-wrap items-center gap-x-4 gap-y-1 text-[11px] text-muted-foreground">
                        <span>
                          <strong className="text-foreground">Account:</strong>{" "}
                          {acct?.name || flag.reportedUserId || "Unknown"}
                          {acct?.email ? ` (${acct.email})` : ""}
                          {acct?.registrationNumber ? ` • ${acct.registrationNumber}` : ""}
                        </span>
                        <span>
                          <strong className="text-foreground">Total Account Flags:</strong>{" "}
                          {acct?.totalFlags ?? 1}
                        </span>
                        <span>
                          <strong className="text-foreground">Reported by:</strong>{" "}
                          {flag.reporterName || flag.reporterUserId}
                        </span>
                        <span className="font-mono">
                          {formatDate(new Date(flag.createdAt).toISOString())}
                        </span>
                      </div>

                      {flag.resolutionNotes && (
                        <p className="text-[11px] text-muted-foreground italic">
                          Admin Note: {flag.resolutionNotes}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-1.5 flex-wrap shrink-0 lg:max-w-[260px] lg:justify-end">
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs gap-1"
                        disabled={isActionPending}
                        onClick={() =>
                          openActionDialog({
                            kind: "flag",
                            flag,
                            action: "DISMISS",
                            title: "Dismiss Flag",
                            description: "Mark this flag as false positive and keep the message visible.",
                            defaultReason: "Reviewed and cleared as false positive",
                          })
                        }
                      >
                        <CheckCircle2 className="h-3 w-3" /> Dismiss
                      </Button>
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs gap-1"
                        disabled={isActionPending}
                        onClick={() =>
                          openActionDialog({
                            kind: "flag",
                            flag,
                            action: "HIDE_MESSAGE",
                            title: "Hide Flagged Message",
                            description: "Hide this message across all synced clients while leaving the account active.",
                            defaultReason: flag.matchedPatterns?.[0] || "Inappropriate content hidden by admin",
                          })
                        }
                      >
                        <EyeOff className="h-3 w-3" /> Hide Msg
                      </Button>
                      {isRestricted ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="h-7 text-xs gap-1 text-emerald-600 border-emerald-500/40 hover:bg-emerald-500/10"
                          disabled={isActionPending}
                          onClick={() =>
                            openActionDialog({
                              kind: "flag",
                              flag,
                              action: "RESTORE_ACCOUNT",
                              title: "Restore Account Access",
                              description: `Restore Mesh Chat posting & Passport key access for ${acct?.name || flag.reportedUserId}.`,
                              defaultReason: "Appeal reviewed; Mesh Chat access restored",
                            })
                          }
                        >
                          <UserCheck className="h-3 w-3" /> Restore Account
                        </Button>
                      ) : (
                        <>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs gap-1 text-amber-600 border-amber-500/40 hover:bg-amber-500/10"
                            disabled={isActionPending}
                            onClick={() =>
                              openActionDialog({
                                kind: "flag",
                                flag,
                                action: "RESTRICT_ACCOUNT",
                                title: "Restrict Account from Mesh Chat",
                                description: `Block ${acct?.name || flag.reportedUserId} from posting or creating Mesh Chat channels and hide this message.`,
                                defaultReason:
                                  flag.matchedPatterns?.[0] || `${flag.severity} ${flag.category} violation`,
                                destructive: true,
                              })
                            }
                          >
                            <UserX className="h-3 w-3" /> Restrict User
                          </Button>
                          <Button
                            size="sm"
                            variant="destructive"
                            className="h-7 text-xs gap-1"
                            disabled={isActionPending}
                            onClick={() =>
                              openActionDialog({
                                kind: "flag",
                                flag,
                                action: "REVOKE_KEY",
                                title: "Revoke Passport Key & Ban Account",
                                description: `Revoke ${acct?.name || flag.reportedUserId}'s Passport Ed25519 key (rejected across offline BLE mesh too) and block Mesh Chat access.`,
                                defaultReason:
                                  flag.matchedPatterns?.[0] || `Critical ${flag.category} violation`,
                                destructive: true,
                              })
                            }
                          >
                            <KeyRound className="h-3 w-3" /> Revoke Key
                          </Button>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-7 text-xs gap-1 text-rose-600 border-rose-500/40 hover:bg-rose-500/10"
                            disabled={isActionPending}
                            onClick={() =>
                              openActionDialog({
                                kind: "flag",
                                flag,
                                action: "RESTRICT_CHANNEL",
                                title: "Dismantle & Restrict Channel",
                                description: `Dismantle and lock channel "${flag.channelId}" where this flagged message was sent. Once dismantled, no users can send messages in this channel.`,
                                defaultReason: `Channel dismantled by administrator due to ${flag.category} violation`,
                                destructive: true,
                              })
                            }
                          >
                            <ShieldAlert className="h-3 w-3" /> Restrict Channel
                          </Button>
                        </>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </TabsContent>

        {/* TAB 2: FLAGGED ACCOUNTS CONTROL */}
        <TabsContent value="accounts" className="space-y-4">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-2 flex-wrap">
              {(["ALL", "ACTIVE", "RESTRICTED", "REVOKED"] as const).map((st) => (
                <Button
                  key={st}
                  size="sm"
                  variant={accountFilter === st ? "default" : "outline"}
                  onClick={() => setAccountFilter(st)}
                  className="h-7 text-xs"
                >
                  {st}
                </Button>
              ))}
            </div>
            <span className="text-xs font-mono text-muted-foreground">
              {visibleAccounts.length} account(s)
            </span>
          </div>

          {isAccountsLoading ? (
            <Skeleton className="h-32 w-full" />
          ) : visibleAccounts.length === 0 ? (
            <EmptyState
              icon={ShieldCheck}
              title="No Flagged Accounts"
              description="No accounts have active or historical Mesh Chat moderation flags in this filter."
            />
          ) : (
            <div className="space-y-3">
              {visibleAccounts.map((acct) => {
                const isRestricted = acct.accountStatus !== "ACTIVE"
                return (
                  <div
                    key={acct.userId || acct.name}
                    className="rounded-xl border border-border/80 bg-card p-4 flex flex-col lg:flex-row lg:items-center justify-between gap-4 text-xs"
                  >
                    <div className="space-y-2 flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-semibold text-sm text-foreground">{acct.name}</span>
                        <Badge variant="secondary" className="text-[10px] font-mono uppercase">
                          {acct.role}
                        </Badge>
                        <Badge
                          variant={
                            acct.accountStatus === "REVOKED"
                              ? "destructive"
                              : acct.accountStatus === "RESTRICTED"
                              ? "warning"
                              : "success"
                          }
                          className="text-[10px] font-mono"
                        >
                          {acct.accountStatus}
                        </Badge>
                        <Badge variant="outline" className="text-[10px] font-mono">
                          Key: {acct.keyStatus}
                        </Badge>
                        <Badge variant="outline" className="text-[10px] font-mono">
                          {acct.totalFlags} Flag(s) • {acct.criticalFlags} Critical/High
                        </Badge>
                      </div>

                      <p className="text-[11px] text-muted-foreground font-mono">
                        {acct.email || acct.userId}
                        {acct.registrationNumber ? ` • Reg: ${acct.registrationNumber}` : ""}
                        {acct.lastFlaggedAt
                          ? ` • Last Flagged: ${formatDate(new Date(acct.lastFlaggedAt).toISOString())}`
                          : ""}
                      </p>

                      {/* Aggregated reasons why this account was flagged */}
                      <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="font-semibold text-foreground">Flagged for:</span>
                        {(acct.reasons.length ? acct.reasons : ["Policy violation"]).map((reason) => (
                          <Badge key={reason} variant="warning" className="text-[10px]">
                            {reason}
                          </Badge>
                        ))}
                      </div>

                      {acct.restrictionReason && (
                        <p className="text-[11px] text-rose-600 dark:text-rose-400">
                          <strong>Restriction Reason:</strong> {acct.restrictionReason}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-2 shrink-0 flex-wrap">
                      {isRestricted ? (
                        <Button
                          size="sm"
                          variant="outline"
                          className="h-8 text-xs gap-1.5 text-emerald-600 border-emerald-500/40 hover:bg-emerald-500/10"
                          onClick={() =>
                            openActionDialog({
                              kind: "account",
                              account: acct,
                              action: "RESTORE",
                              title: "Restore Account Access",
                              description: `Re-enable Mesh Chat messaging and restore Passport key status for ${acct.name}.`,
                              defaultReason: "Reviewed and cleared by administrator",
                            })
                          }
                        >
                          <UserCheck className="h-3.5 w-3.5" /> Restore Account
                        </Button>
                      ) : (
                        <>
                          <Button
                            size="sm"
                            variant="outline"
                            className="h-8 text-xs gap-1.5 text-amber-600 border-amber-500/40 hover:bg-amber-500/10"
                            onClick={() =>
                              openActionDialog({
                                kind: "account",
                                account: acct,
                                action: "RESTRICT",
                                title: "Restrict Account",
                                description: `Prevent ${acct.name} from sending or syncing Mesh Chat messages.`,
                                defaultReason: acct.reasons[0] || "Repeated Mesh Chat violations",
                                destructive: true,
                              })
                            }
                          >
                            <UserX className="h-3.5 w-3.5" /> Restrict Chat
                          </Button>
                          <Button
                            size="sm"
                            variant="destructive"
                            className="h-8 text-xs gap-1.5"
                            onClick={() =>
                              openActionDialog({
                                kind: "account",
                                account: acct,
                                action: "REVOKE_KEY",
                                title: "Revoke Key & Ban Account",
                                description: `Revoke ${acct.name}'s cryptographic Passport identity across the BLE mesh and block Mesh Chat access.`,
                                defaultReason: acct.reasons[0] || "Critical safety/crime threat",
                                destructive: true,
                              })
                            }
                          >
                            <KeyRound className="h-3.5 w-3.5" /> Revoke Key
                          </Button>
                        </>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          )}
        </TabsContent>

        {/* TAB 3: CHANNELS & EMERGENCY FLARE */}
        <TabsContent value="channels" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-4 gap-5">
            <div className="rounded-xl border border-border/80 bg-card p-3 space-y-1.5 h-fit">
              <p className="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                Active Mesh Channels
              </p>
              {channels.map((ch) => {
                const isSelected = ch.channelId === selectedChannel
                const isEmergency = ch.channelId === "channel:emergency"
                return (
                  <button
                    key={ch.channelId}
                    type="button"
                    onClick={() => setSelectedChannel(ch.channelId)}
                    className={`w-full text-left px-3 py-2 rounded-lg text-xs transition-colors flex items-center justify-between gap-2 ${
                      isSelected
                        ? "bg-accent text-accent-foreground font-semibold"
                        : "text-muted-foreground hover:bg-accent/50 hover:text-foreground"
                    }`}
                  >
                    <span className="flex items-center gap-2 truncate">
                      {isEmergency ? (
                        <AlertTriangle className="h-3.5 w-3.5 text-rose-500 shrink-0" />
                      ) : (
                        <Hash className="h-3.5 w-3.5 shrink-0" />
                      )}
                      <span className="truncate">{ch.name}</span>
                    </span>
                    <div className="flex items-center gap-1 shrink-0">
                      {ch.isRestricted && (
                        <Badge variant="destructive" className="text-[9px] px-1 py-0">
                          RESTRICTED
                        </Badge>
                      )}
                      {isEmergency && (
                        <Badge variant="destructive" className="text-[9px] px-1 py-0">
                          DEAN
                        </Badge>
                      )}
                    </div>
                  </button>
                )
              })}
            </div>

            <div className="lg:col-span-3 rounded-xl border border-border/80 bg-card flex flex-col overflow-hidden">
              <div className="p-4 border-b border-border/70 flex items-center justify-between bg-muted/20">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-sm font-semibold text-foreground">{selectedChannel}</h3>
                    {channels.find((c) => c.channelId === selectedChannel)?.isRestricted && (
                      <Badge variant="destructive" className="text-[10px]">
                        Dismantled / Restricted
                      </Badge>
                    )}
                  </div>
                  <p className="text-[11px] text-muted-foreground">
                    {selectedChannel === "channel:emergency"
                      ? "Official Dean / Warden Emergency Flare broadcast channel (privileged roles only)"
                      : "Synchronized campus mesh discussion channel"}
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  {selectedChannel !== "channel:emergency" && (
                    channels.find((c) => c.channelId === selectedChannel)?.isRestricted ? (
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs text-emerald-600 border-emerald-500/40 hover:bg-emerald-500/10"
                        onClick={() =>
                          openActionDialog({
                            kind: "channel",
                            channelId: selectedChannel,
                            action: "RESTORE",
                            title: "Restore Channel",
                            description: `Restore channel "${selectedChannel}" so users can resume messaging.`,
                            defaultReason: "Channel restored by administrator",
                          })
                        }
                      >
                        Restore Channel
                      </Button>
                    ) : (
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 text-xs text-rose-600 border-rose-500/40 hover:bg-rose-500/10"
                        onClick={() =>
                          openActionDialog({
                            kind: "channel",
                            channelId: selectedChannel,
                            action: "RESTRICT",
                            title: "Dismantle & Restrict Channel",
                            description: `Dismantle channel "${selectedChannel}". Once dismantled, messaging is disabled for all users.`,
                            defaultReason: "Channel dismantled by administrator",
                            destructive: true,
                          })
                        }
                      >
                        Dismantle Channel
                      </Button>
                    )
                  )}
                  <Badge variant="outline" className="font-mono text-[10px]">
                    {messages.length} Messages
                  </Badge>
                </div>
              </div>

              <div className="p-4 space-y-2.5 max-h-[420px] overflow-y-auto">
                {isMsgsLoading ? (
                  <div className="space-y-2">
                    <Skeleton className="h-14 w-full" />
                    <Skeleton className="h-14 w-full" />
                  </div>
                ) : messages.length === 0 ? (
                  <EmptyState
                    icon={Radio}
                    title="No messages in this channel"
                    description="Broadcast an announcement or emergency flare below."
                    compact
                  />
                ) : (
                  messages.map((m) => (
                    <div
                      key={m.messageId}
                      className={`rounded-xl border p-3 text-xs space-y-1.5 ${
                        selectedChannel === "channel:emergency"
                          ? "border-rose-500/30 bg-rose-500/5"
                          : m.moderationStatus && m.moderationStatus !== "CLEAN"
                          ? "border-amber-500/40 bg-amber-500/5"
                          : "border-border/70 bg-background"
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span className="font-semibold text-foreground">{m.senderDisplayName}</span>
                          <Badge variant="secondary" className="text-[9px] font-mono uppercase">
                            {m.senderRole}
                          </Badge>
                          {m.signatureVerified && (
                            <Badge variant="success" className="text-[9px] font-mono">
                              Ed25519 Verified
                            </Badge>
                          )}
                          {m.moderationStatus && m.moderationStatus !== "CLEAN" && (
                            <Badge variant="warning" className="text-[9px] font-mono">
                              {m.moderationStatus}
                            </Badge>
                          )}
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-[10px] text-muted-foreground font-mono">
                            {formatDate(new Date(m.createdAt).toISOString())}
                          </span>
                          {selectedChannel !== "channel:emergency" && (
                            <Button
                              size="sm"
                              variant="ghost"
                              className="h-6 px-2 text-[10px] text-rose-600 hover:text-rose-700 hover:bg-rose-500/10 gap-1"
                              onClick={() =>
                                openActionDialog({
                                  kind: "message",
                                  message: m,
                                  title: "Flag & Hide Message",
                                  description: `Hide this message from ${m.senderDisplayName} and log a moderation flag.`,
                                  defaultReason: "Flagged by administrator in channel feed",
                                  destructive: true,
                                })
                              }
                            >
                              <Flag className="h-3 w-3" /> Flag
                            </Button>
                          )}
                        </div>
                      </div>
                      <p className="text-foreground leading-relaxed">{m.text}</p>
                    </div>
                  ))
                )}
              </div>

              <form
                onSubmit={(e) => {
                  e.preventDefault()
                  if (broadcastText.trim()) broadcastMutation.mutate()
                }}
                className="p-3.5 border-t border-border/70 bg-muted/10 flex items-center gap-2"
              >
                <Input
                  value={broadcastText}
                  onChange={(e) => setBroadcastText(e.target.value)}
                  placeholder={
                    selectedChannel === "channel:emergency"
                      ? "Dispatch official Emergency Flare alert to all mesh nodes..."
                      : `Post to ${selectedChannel}...`
                  }
                  className="h-9 text-xs"
                />
                <Button
                  type="submit"
                  size="sm"
                  variant={selectedChannel === "channel:emergency" ? "destructive" : "default"}
                  disabled={!broadcastText.trim()}
                  loading={broadcastMutation.isPending}
                  className="h-9 gap-1.5 text-xs shrink-0"
                >
                  <Send className="h-3.5 w-3.5" />
                  {selectedChannel === "channel:emergency" ? "Dispatch Flare" : "Broadcast"}
                </Button>
              </form>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      {/* Moderation Reason / Confirmation Dialog */}
      <Dialog open={!!pendingAction} onOpenChange={(open) => !open && setPendingAction(null)}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>{pendingAction?.title}</DialogTitle>
            <DialogDescription>{pendingAction?.description}</DialogDescription>
          </DialogHeader>
          <div className="space-y-2 py-2 text-xs">
            <label className="font-medium text-foreground">Reason / Audit Note</label>
            <Input
              value={actionNotes}
              onChange={(e) => setActionNotes(e.target.value)}
              placeholder="Enter reason recorded on the moderation audit trail..."
              className="h-9 text-xs"
            />
          </div>
          <DialogFooter>
            <Button variant="outline" size="sm" onClick={() => setPendingAction(null)}>
              Cancel
            </Button>
            <Button
              size="sm"
              variant={pendingAction?.destructive ? "destructive" : "default"}
              loading={isActionPending}
              onClick={handleConfirmPendingAction}
            >
              Confirm Action
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Create Channel Dialog */}
      <Dialog open={newChannelOpen} onOpenChange={setNewChannelOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Create Campus Mesh Channel</DialogTitle>
            <DialogDescription>
              Create a new public broadcast or coordination channel across the mesh relay.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-3 py-2 text-xs">
            <div className="space-y-1">
              <label className="font-medium text-foreground">Channel Name (slug)</label>
              <Input
                value={channelName}
                onChange={(e) => setChannelName(e.target.value)}
                placeholder="e.g. exam-alerts"
                className="h-8 text-xs font-mono"
              />
            </div>
            <div className="space-y-1">
              <label className="font-medium text-foreground">Description</label>
              <Input
                value={channelDesc}
                onChange={(e) => setChannelDesc(e.target.value)}
                placeholder="Purpose of this mesh channel..."
                className="h-8 text-xs"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" size="sm" onClick={() => setNewChannelOpen(false)}>
              Cancel
            </Button>
            <Button
              size="sm"
              disabled={!channelName.trim()}
              loading={createChannelMutation.isPending}
              onClick={() => createChannelMutation.mutate()}
            >
              Create Channel
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

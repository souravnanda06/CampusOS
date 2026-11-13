import * as React from "react"
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"
import { useLocation } from "react-router-dom"
import {
  Sparkles,
  Send,
  Paperclip,
  X,
  CheckCircle2,
  AlertCircle,
  Loader2,
  Bot,
  Trash2,
} from "lucide-react"
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"
import { useToast } from "@/components/ui/toast"
import {
  copilotApi,
  CopilotCard,
  CopilotPendingAction,
} from "./api/copilot-api"

interface ChatEntry {
  id: string
  role: "user" | "assistant"
  text: string
  cards?: CopilotCard[]
  pendingActions?: CopilotPendingAction[]
  toolsUsed?: string[]
  attachmentNames?: string[]
  isError?: boolean
}

interface CopilotDrawerProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CopilotDrawer({ open, onOpenChange }: CopilotDrawerProps) {
  const location = useLocation()
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [messages, setMessages] = React.useState<ChatEntry[]>([])
  const [input, setInput] = React.useState("")
  const [files, setFiles] = React.useState<File[]>([])
  const [actionStates, setActionStates] = React.useState<Record<string, "EXECUTED" | "DISMISSED">>({})
  const scrollRef = React.useRef<HTMLDivElement>(null)
  const fileInputRef = React.useRef<HTMLInputElement>(null)

  const { data: suggestionData } = useQuery({
    queryKey: ["copilot", "suggestions"],
    queryFn: copilotApi.getSuggestions,
    enabled: open,
    retry: false,
  })

  const chatMutation = useMutation({
    mutationFn: (payload: { text: string; attachFiles: File[] }) =>
      copilotApi.chat({
        message: payload.text,
        history: messages.map((m) => ({ role: m.role, text: m.text })),
        screenContext: `admin_web:${location.pathname}`,
        files: payload.attachFiles,
      }),
    onSuccess: (res) => {
      setMessages((prev) => [
        ...prev,
        {
          id: `asst_${Date.now()}`,
          role: "assistant",
          text: res.reply,
          cards: res.cards,
          pendingActions: res.pendingActions,
          toolsUsed: res.toolsUsed,
        },
      ])
    },
    onError: (err: unknown) => {
      const msg = err instanceof Error ? err.message : "Failed to contact Campus AI Copilot"
      setMessages((prev) => [
        ...prev,
        {
          id: `err_${Date.now()}`,
          role: "assistant",
          text: msg,
          isError: true,
        },
      ])
    },
  })

  const confirmMutation = useMutation({
    mutationFn: (actionId: string) => copilotApi.confirmAction(actionId),
    onSuccess: (res) => {
      setActionStates((prev) => ({ ...prev, [res.actionId]: "EXECUTED" }))
      toast({
        title: "Copilot Action Executed",
        description: res.message || "Administrative action completed.",
        type: "success",
      })
      queryClient.invalidateQueries()
    },
    onError: (err: unknown) => {
      toast({
        title: "Execution Failed",
        description: err instanceof Error ? err.message : "Could not execute drafted action",
        type: "error",
      })
    },
  })

  React.useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages, chatMutation.isPending])

  const handleSend = (promptOverride?: string) => {
    const text = (promptOverride ?? input).trim()
    if (!text && files.length === 0) return
    if (chatMutation.isPending) return

    const attachFiles = [...files]
    setMessages((prev) => [
      ...prev,
      {
        id: `usr_${Date.now()}`,
        role: "user",
        text: text || `Analyze ${attachFiles.map((f) => f.name).join(", ")}`,
        attachmentNames: attachFiles.map((f) => f.name),
      },
    ])
    if (!promptOverride) setInput("")
    setFiles([])
    chatMutation.mutate({ text, attachFiles })
  }

  const handleFilePick = (e: React.ChangeEvent<HTMLInputElement>) => {
    const picked = Array.from(e.target.files || [])
    if (picked.length) {
      setFiles((prev) => [...prev, ...picked].slice(0, 3))
    }
    e.target.value = ""
  }

  const suggestions = suggestionData?.suggestions || []

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-lg flex flex-col p-0">
        <SheetHeader className="px-6 py-4 border-b border-border/70">
          <div className="flex items-center justify-between pr-6">
            <div className="flex items-center gap-2.5">
              <div className="flex h-8 w-8 items-center justify-center rounded-xl bg-primary/10 text-primary border border-primary/20">
                <Sparkles className="h-4 w-4" />
              </div>
              <div>
                <SheetTitle className="text-sm font-semibold">Campus AI Copilot</SheetTitle>
                <SheetDescription className="text-[11px]">
                  Role-scoped administrative assistant &amp; action drafting
                </SheetDescription>
              </div>
            </div>
            {messages.length > 0 && (
              <Button
                variant="ghost"
                size="icon-sm"
                onClick={() => setMessages([])}
                title="Clear conversation"
                className="text-muted-foreground hover:text-foreground"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </Button>
            )}
          </div>
        </SheetHeader>

        {/* Chat Stream */}
        <div ref={scrollRef} className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          {messages.length === 0 ? (
            <div className="space-y-4 py-4">
              <div className="rounded-xl border border-border/80 bg-muted/30 p-4 space-y-2">
                <div className="flex items-center gap-2 text-xs font-semibold text-foreground">
                  <Bot className="h-4 w-4 text-primary" />
                  <span>Command Plane Intelligence</span>
                </div>
                <p className="text-xs text-muted-foreground leading-relaxed">
                  Query live complaints, SLA breaches, pending student approvals, fees, or mess ratings — or draft notices and escalations for confirmation.
                </p>
              </div>

              {suggestions.length > 0 && (
                <div className="space-y-2">
                  <p className="text-[10px] font-semibold uppercase tracking-wider text-muted-foreground">
                    Quick Prompts
                  </p>
                  <div className="grid grid-cols-1 gap-2">
                    {suggestions.map((s) => (
                      <button
                        key={s.label}
                        type="button"
                        onClick={() => handleSend(s.prompt)}
                        className="text-left rounded-xl border border-border/80 bg-card px-3.5 py-2.5 hover:border-primary/40 hover:bg-accent/40 transition-colors space-y-0.5"
                      >
                        <p className="text-xs font-semibold text-foreground">{s.label}</p>
                        <p className="text-[11px] text-muted-foreground line-clamp-1">{s.prompt}</p>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            messages.map((m) => (
              <div
                key={m.id}
                className={`flex flex-col gap-2 ${m.role === "user" ? "items-end" : "items-start"}`}
              >
                <div
                  className={`max-w-[90%] rounded-2xl px-3.5 py-2.5 text-xs leading-relaxed whitespace-pre-wrap ${
                    m.role === "user"
                      ? "bg-primary text-primary-foreground rounded-br-sm"
                      : m.isError
                      ? "bg-destructive/10 text-destructive border border-destructive/30"
                      : "bg-card border border-border/80 text-foreground rounded-bl-sm shadow-2xs"
                  }`}
                >
                  {m.attachmentNames && m.attachmentNames.length > 0 && (
                    <div className="flex flex-wrap gap-1 mb-1.5">
                      {m.attachmentNames.map((n) => (
                        <Badge key={n} variant="secondary" className="text-[10px] font-mono">
                          {n}
                        </Badge>
                      ))}
                    </div>
                  )}
                  {m.text}
                </div>

                {/* Structured Insight Cards */}
                {m.cards && m.cards.length > 0 && (
                  <div className="w-full space-y-2">
                    {m.cards.map((card, idx) => (
                      <div
                        key={idx}
                        className="rounded-xl border border-border/80 bg-card p-3 space-y-2 text-xs shadow-2xs"
                      >
                        <p className="font-semibold text-foreground text-[11px] uppercase tracking-wider">
                          {card.title}
                        </p>
                        {card.items && card.items.length > 0 && (
                          <div className="grid grid-cols-2 gap-2">
                            {card.items.map((it) => (
                              <div key={it.label} className="rounded-lg bg-muted/40 px-2.5 py-1.5">
                                <p className="text-[10px] text-muted-foreground">{it.label}</p>
                                <p className="font-mono font-bold text-foreground">{it.value}</p>
                              </div>
                            ))}
                          </div>
                        )}
                        {card.rows && card.rows.length > 0 && (
                          <div className="divide-y divide-border/50">
                            {card.rows.map((r, rIdx) => (
                              <div key={rIdx} className="py-1.5 flex items-center justify-between gap-2">
                                <div className="min-w-0">
                                  <p className="font-medium text-foreground truncate">{r.title}</p>
                                  {r.subtitle && (
                                    <p className="text-[10px] text-muted-foreground truncate">{r.subtitle}</p>
                                  )}
                                </div>
                                {r.badge && (
                                  <Badge variant="outline" className="font-mono text-[10px] shrink-0">
                                    {r.badge}
                                  </Badge>
                                )}
                              </div>
                            ))}
                          </div>
                        )}
                        {card.summary && (
                          <p className="text-[11px] text-muted-foreground leading-relaxed">{card.summary}</p>
                        )}
                      </div>
                    ))}
                  </div>
                )}

                {/* Pending Action Confirmation Cards */}
                {m.pendingActions && m.pendingActions.length > 0 && (
                  <div className="w-full space-y-2">
                    {m.pendingActions.map((act) => {
                      const state = actionStates[act.actionId]
                      return (
                        <div
                          key={act.actionId}
                          className="rounded-xl border border-primary/30 bg-primary/5 p-3.5 space-y-2.5 text-xs"
                        >
                          <div className="flex items-start justify-between gap-2">
                            <div>
                              <Badge variant="info" className="text-[9px] font-mono mb-1">
                                {act.actionType}
                              </Badge>
                              <p className="font-semibold text-foreground">{act.title}</p>
                            </div>
                            {state === "EXECUTED" && (
                              <Badge variant="success" className="text-[10px] gap-1">
                                <CheckCircle2 className="h-3 w-3" /> Executed
                              </Badge>
                            )}
                          </div>
                          <p className="text-[11px] text-muted-foreground leading-relaxed">{act.summary}</p>

                          {!state && (
                            <div className="flex items-center gap-2 pt-1">
                              <Button
                                size="sm"
                                className="h-7 text-xs gap-1"
                                disabled={confirmMutation.isPending}
                                onClick={() => confirmMutation.mutate(act.actionId)}
                              >
                                <CheckCircle2 className="h-3 w-3" />
                                Confirm &amp; Execute
                              </Button>
                              <Button
                                size="sm"
                                variant="ghost"
                                className="h-7 text-xs"
                                onClick={() =>
                                  setActionStates((prev) => ({ ...prev, [act.actionId]: "DISMISSED" }))
                                }
                              >
                                Dismiss
                              </Button>
                            </div>
                          )}
                          {state === "DISMISSED" && (
                            <p className="text-[10px] text-muted-foreground italic flex items-center gap-1">
                              <AlertCircle className="h-3 w-3" /> Draft dismissed
                            </p>
                          )}
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>
            ))
          )}

          {chatMutation.isPending && (
            <div className="flex items-center gap-2 text-xs text-muted-foreground px-1">
              <Loader2 className="h-3.5 w-3.5 animate-spin text-primary" />
              <span>Analyzing institutional telemetry...</span>
            </div>
          )}
        </div>

        {/* Input Composer */}
        <div className="border-t border-border/70 p-4 space-y-2 bg-card/50">
          {files.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {files.map((f, i) => (
                <span
                  key={`${f.name}-${i}`}
                  className="inline-flex items-center gap-1 rounded-md border border-border bg-muted/50 px-2 py-0.5 text-[10px] font-mono"
                >
                  {f.name}
                  <button
                    type="button"
                    onClick={() => setFiles((prev) => prev.filter((_, idx) => idx !== i))}
                    className="text-muted-foreground hover:text-foreground"
                  >
                    <X className="h-3 w-3" />
                  </button>
                </span>
              ))}
            </div>
          )}

          <form
            onSubmit={(e) => {
              e.preventDefault()
              handleSend()
            }}
            className="flex items-center gap-2"
          >
            <input
              ref={fileInputRef}
              type="file"
              accept=".pdf,.txt,.md,.csv,.png,.jpg,.jpeg,.webp"
              multiple
              className="hidden"
              onChange={handleFilePick}
            />
            <Button
              type="button"
              variant="outline"
              size="icon-sm"
              className="h-9 w-9 shrink-0"
              onClick={() => fileInputRef.current?.click()}
              title="Attach document or image (max 3)"
            >
              <Paperclip className="h-4 w-4" />
            </Button>
            <Input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="Ask Campus AI or draft an admin action..."
              className="h-9 text-xs"
              disabled={chatMutation.isPending}
            />
            <Button
              type="submit"
              size="icon-sm"
              className="h-9 w-9 shrink-0"
              disabled={chatMutation.isPending || (!input.trim() && files.length === 0)}
            >
              <Send className="h-4 w-4" />
            </Button>
          </form>
        </div>
      </SheetContent>
    </Sheet>
  )
}

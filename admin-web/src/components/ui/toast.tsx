import * as React from "react"
import { CheckCircle2, AlertCircle, Info, X } from "lucide-react"
import { cn } from "@/lib/utils"

export type ToastType = "success" | "error" | "info"

export interface ToastItem {
  id: string
  title: string
  description?: string
  message?: string
  type?: ToastType
  duration?: number
}

interface ToastContextType {
  toast: (item: Omit<ToastItem, "id">) => void
  addToast: (item: Omit<ToastItem, "id">) => void
  success: (title: string, description?: string) => void
  error: (title: string, description?: string) => void
  info: (title: string, description?: string) => void
}

const ToastContext = React.createContext<ToastContextType | undefined>(undefined)

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<ToastItem[]>([])

  const removeToast = React.useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
  }, [])

  const addToast = React.useCallback(
    ({ title, description, message, type = "info", duration = 4000 }: Omit<ToastItem, "id">) => {
      const id = Math.random().toString(36).substring(2, 9)
      const desc = description || message
      setToasts((prev) => [...prev.slice(-4), { id, title, description: desc, message: desc, type, duration }])

      if (duration > 0) {
        setTimeout(() => {
          removeToast(id)
        }, duration)
      }
    },
    [removeToast]
  )

  const success = React.useCallback(
    (title: string, description?: string) => addToast({ title, description, type: "success" }),
    [addToast]
  )

  const error = React.useCallback(
    (title: string, description?: string) => addToast({ title, description, type: "error" }),
    [addToast]
  )

  const info = React.useCallback(
    (title: string, description?: string) => addToast({ title, description, type: "info" }),
    [addToast]
  )

  return (
    <ToastContext.Provider value={{ toast: addToast, addToast, success, error, info }}>
      {children}
      <div
        className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none max-w-sm w-full"
        aria-live="polite"
      >
        {toasts.map((t) => {
          let Icon = Info
          let iconColor = "text-sky-500"
          let borderColor = "border-border"

          if (t.type === "success") {
            Icon = CheckCircle2
            iconColor = "text-emerald-500"
            borderColor = "border-emerald-500/30"
          } else if (t.type === "error") {
            Icon = AlertCircle
            iconColor = "text-rose-500"
            borderColor = "border-rose-500/30"
          }

          return (
            <div
              key={t.id}
              className={cn(
                "pointer-events-auto flex items-start gap-3 rounded-xl border bg-card p-3.5 shadow-lg animate-in slide-in-from-bottom-2 fade-in-0 duration-200",
                borderColor
              )}
            >
              <Icon className={cn("h-4 w-4 mt-0.5 shrink-0", iconColor)} />
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-foreground tracking-tight">{t.title}</p>
                {t.description && (
                  <p className="text-xs text-muted-foreground leading-relaxed mt-0.5">
                    {t.description}
                  </p>
                )}
              </div>
              <button
                onClick={() => removeToast(t.id)}
                className="text-muted-foreground hover:text-foreground shrink-0 rounded p-0.5 transition-colors"
                aria-label="Dismiss toast"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          )
        })}
      </div>
    </ToastContext.Provider>
  )
}

export function useToast() {
  const context = React.useContext(ToastContext)
  if (!context) {
    throw new Error("useToast must be used within a ToastProvider")
  }
  return context
}

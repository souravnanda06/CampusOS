import * as React from "react"
import { cn } from "@/lib/utils"

export type StatusType = "success" | "warning" | "error" | "pending" | "info" | "neutral"

interface StatusIndicatorProps extends React.HTMLAttributes<HTMLSpanElement> {
  status: StatusType | string
  label?: string
  pulse?: boolean
  size?: "sm" | "md" | "lg"
}

export function StatusIndicator({
  status,
  label,
  pulse = false,
  size = "md",
  className,
  ...props
}: StatusIndicatorProps) {
  const normalized = status.toLowerCase()

  let dotColor = "bg-slate-400"
  let textColor = "text-muted-foreground"

  if (["success", "active", "resolved", "approved", "valid", "present", "published"].includes(normalized)) {
    dotColor = "bg-emerald-500"
    textColor = "text-emerald-700 dark:text-emerald-400"
  } else if (["warning", "attention", "pending", "assigned", "in_progress", "reopened", "overdue"].includes(normalized)) {
    dotColor = "bg-amber-500"
    textColor = "text-amber-700 dark:text-amber-400"
  } else if (["error", "critical", "rejected", "closed", "revoked", "suspended", "absent"].includes(normalized)) {
    dotColor = "bg-rose-500"
    textColor = "text-rose-700 dark:text-rose-400"
  } else if (["info", "draft", "device_bound"].includes(normalized)) {
    dotColor = "bg-sky-500"
    textColor = "text-sky-700 dark:text-sky-400"
  }

  const dotSizes = {
    sm: "h-1.5 w-1.5",
    md: "h-2 w-2",
    lg: "h-2.5 w-2.5",
  }

  return (
    <span className={cn("inline-flex items-center gap-1.5 font-medium text-xs", textColor, className)} {...props}>
      <span className="relative flex items-center justify-center">
        {pulse && (
          <span
            className={cn(
              "absolute inline-flex h-full w-full animate-ping rounded-full opacity-75",
              dotColor
            )}
          />
        )}
        <span className={cn("relative inline-flex rounded-full", dotSizes[size], dotColor)} />
      </span>
      {label && <span>{label}</span>}
    </span>
  )
}

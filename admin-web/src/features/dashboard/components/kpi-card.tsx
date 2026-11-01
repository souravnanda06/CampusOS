import * as React from "react"
import { LucideIcon } from "lucide-react"
import { cn } from "@/lib/utils"

interface KpiCardProps {
  title: string
  value: React.ReactNode
  subValue?: string
  icon: LucideIcon
  alert?: boolean
  trend?: {
    label: string
    positive?: boolean
  }
  badge?: React.ReactNode
  onClick?: () => void
  className?: string
}

export function KpiCard({
  title,
  value,
  subValue,
  icon: Icon,
  alert = false,
  trend,
  badge,
  onClick,
  className,
}: KpiCardProps) {
  return (
    <div
      onClick={onClick}
      className={cn(
        "flex flex-col justify-between rounded-xl border bg-card p-4 transition-all duration-150 select-none",
        alert
          ? "border-amber-500/40 bg-amber-500/[0.02]"
          : "border-border/80 hover:border-border",
        onClick && "cursor-pointer hover:shadow-sm active:scale-[0.99]",
        className
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <div className="space-y-0.5 min-w-0">
          <p className="text-xs font-medium text-muted-foreground truncate">{title}</p>
          <div className="flex items-baseline gap-2">
            <h3 className="text-2xl font-bold tracking-tight text-foreground">{value}</h3>
            {badge}
          </div>
        </div>
        <div
          className={cn(
            "flex h-8 w-8 items-center justify-center rounded-lg shrink-0",
            alert
              ? "bg-amber-500/10 text-amber-600 dark:text-amber-400"
              : "bg-muted text-muted-foreground"
          )}
        >
          <Icon className="h-4 w-4" />
        </div>
      </div>

      {(subValue || trend) && (
        <div className="mt-3 flex items-center justify-between text-[11px] text-muted-foreground pt-2 border-t border-border/40">
          {subValue && <span className="truncate">{subValue}</span>}
          {trend && (
            <span
              className={cn(
                "font-medium",
                trend.positive
                  ? "text-emerald-600 dark:text-emerald-400"
                  : "text-rose-600 dark:text-rose-400"
              )}
            >
              {trend.label}
            </span>
          )}
        </div>
      )}
    </div>
  )
}

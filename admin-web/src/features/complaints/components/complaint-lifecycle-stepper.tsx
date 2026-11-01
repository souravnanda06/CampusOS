import * as React from "react"
import { Check, Clock, AlertTriangle, XCircle, RotateCcw } from "lucide-react"
import { cn } from "@/lib/utils"

interface ComplaintLifecycleStepperProps {
  status: string
  className?: string
}

export function ComplaintLifecycleStepper({ status, className }: ComplaintLifecycleStepperProps) {
  const normalized = status.toUpperCase()

  const standardSteps = [
    { key: "PENDING", label: "Logged" },
    { key: "ASSIGNED", label: "Assigned" },
    { key: "IN_PROGRESS", label: "In Progress" },
    { key: "RESOLVED", label: "Resolved" },
    { key: "CLOSED", label: "Closed" },
  ]

  const getStepIndex = (key: string) => {
    switch (key) {
      case "PENDING":
        return 0
      case "ASSIGNED":
        return 1
      case "IN_PROGRESS":
        return 2
      case "RESOLVED":
        return 3
      case "CLOSED":
        return 4
      case "REOPENED":
        return 2 // Back in progress
      default:
        return -1
    }
  }

  const currentIndex = getStepIndex(normalized)
  const isRejected = normalized === "REJECTED"
  const isReopened = normalized === "REOPENED"

  if (isRejected) {
    return (
      <div className={cn("flex items-center gap-2 p-3 rounded-lg border border-rose-500/20 bg-rose-500/5 text-xs text-rose-700 dark:text-rose-400 font-medium", className)}>
        <XCircle className="h-4 w-4" />
        <span>Complaint was rejected by administration during triage.</span>
      </div>
    )
  }

  return (
    <div className={cn("space-y-2", className)}>
      <div className="flex items-center justify-between relative">
        {/* Background track line */}
        <div className="absolute left-2 right-2 top-3 h-0.5 bg-border/80 -z-0" />

        {standardSteps.map((step, idx) => {
          const isPassed = currentIndex > idx
          const isCurrent = currentIndex === idx

          return (
            <div key={step.key} className="flex flex-col items-center gap-1.5 relative z-10">
              <div
                className={cn(
                  "flex h-6 w-6 items-center justify-center rounded-full text-[10px] font-mono font-bold transition-all",
                  isPassed
                    ? "bg-emerald-600 text-white"
                    : isCurrent
                    ? "bg-primary text-primary-foreground ring-4 ring-primary/20"
                    : "bg-muted text-muted-foreground border border-border"
                )}
              >
                {isPassed ? <Check className="h-3.5 w-3.5 stroke-[2.5]" /> : idx + 1}
              </div>
              <span
                className={cn(
                  "text-[10px] tracking-tight font-medium select-none",
                  isCurrent ? "text-foreground font-semibold" : "text-muted-foreground"
                )}
              >
                {step.label}
              </span>
            </div>
          )
        })}
      </div>

      {isReopened && (
        <div className="flex items-center gap-1.5 pt-1 text-xs text-amber-600 dark:text-amber-400">
          <RotateCcw className="h-3.5 w-3.5" />
          <span>Ticket was reopened for further operational remediation.</span>
        </div>
      )}
    </div>
  )
}

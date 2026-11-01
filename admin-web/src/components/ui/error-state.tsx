import * as React from "react"
import { AlertCircle, RefreshCw, ShieldAlert, WifiOff } from "lucide-react"
import { Button } from "./button"
import { cn } from "@/lib/utils"

interface ErrorStateProps {
  status?: number
  title?: string
  message?: string
  onRetry?: () => void
  className?: string
  compact?: boolean
}

export function ErrorState({
  status,
  title: customTitle,
  message,
  onRetry,
  className,
  compact = false,
}: ErrorStateProps) {
  let title = customTitle || "Unable to load data"
  let description = message || "An unexpected error occurred while communicating with the CampusOS server."
  let Icon = AlertCircle

  if (status === 401) {
    title = "Session Expired"
    description = "Your administrative authentication session has expired or is invalid. Please sign in again."
    Icon = ShieldAlert
  } else if (status === 403) {
    title = "Access Restricted"
    description = "You do not have the required institutional permissions to view or perform operations on this resource."
    Icon = ShieldAlert
  } else if (status === 404) {
    title = "Record Not Found"
    description = "The requested institutional record or operational entity does not exist or has been removed."
    Icon = AlertCircle
  } else if (status === 0 || message?.toLowerCase().includes("network") || message?.toLowerCase().includes("offline")) {
    title = "Connection Interrupted"
    description = "Unable to reach the CampusOS server. Please check your network connection or verify that the local service is running."
    Icon = WifiOff
  } else if (status && status >= 500) {
    title = "CampusOS Service Problem"
    description = "The server encountered an internal error while processing this operational request. Please try again shortly."
    Icon = AlertCircle
  }

  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center text-center rounded-xl border border-destructive/20 bg-destructive/5",
        compact ? "py-6 px-4" : "py-12 px-6",
        className
      )}
    >
      <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-destructive/10 text-destructive mb-3 ring-4 ring-destructive/10">
        <Icon className="h-5 w-5" />
      </div>
      <h3 className="text-sm font-semibold text-foreground mb-1">
        {title} {status ? <span className="font-mono text-xs font-normal text-muted-foreground">({status})</span> : null}
      </h3>
      <p className="text-xs text-muted-foreground max-w-sm leading-relaxed mb-4">
        {description}
      </p>
      {onRetry && (
        <Button size="sm" variant="outline" onClick={onRetry} className="gap-1.5">
          <RefreshCw className="h-3.5 w-3.5" />
          Retry Request
        </Button>
      )}
    </div>
  )
}

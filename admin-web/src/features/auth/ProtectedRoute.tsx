import * as React from "react"
import { Navigate, useLocation } from "react-router-dom"
import { useAuth } from "./AuthContext"
import { UserRole, isConsoleAuthorizedRole, normalizeRole } from "@/types/auth"
import { ErrorState } from "@/components/ui/error-state"
import { Button } from "@/components/ui/button"

interface ProtectedRouteProps {
  children: React.ReactNode
  allowedRoles?: UserRole[]
}

export function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const { isAuthenticated, user, isLoading, logout } = useAuth()
  const location = useLocation()

  if (isLoading) {
    return (
      <div className="flex h-64 w-full items-center justify-center">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <span className="h-3 w-3 animate-spin rounded-full border-2 border-primary border-t-transparent" />
          Verifying institutional authorization...
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />
  }

  if (user && !isConsoleAuthorizedRole(user.role)) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center px-4 py-12 bg-background">
        <div className="max-w-md w-full space-y-4 text-center">
          <ErrorState
            status={403}
            message={`Your account role (${user.role}) is not authorized for the CampusOS Administrative Control Plane.`}
          />
          <Button variant="outline" size="sm" onClick={logout}>
            Sign Out and Switch Account
          </Button>
        </div>
      </div>
    )
  }

  if (allowedRoles && user) {
    const normalizedAllowed = allowedRoles.map((r) => normalizeRole(r))
    if (!normalizedAllowed.includes(normalizeRole(user.role))) {
      return (
        <div className="py-12">
          <ErrorState
            status={403}
            message={`Your account role (${user.role}) is not authorized to access this operational module.`}
          />
        </div>
      )
    }
  }

  return <>{children}</>
}

import * as React from "react"
import { Navigate, useLocation } from "react-router-dom"
import { useAuth } from "./AuthContext"
import { UserRole } from "@/types/auth"
import { ErrorState } from "@/components/ui/error-state"

interface ProtectedRouteProps {
  children: React.ReactNode
  allowedRoles?: UserRole[]
}

export function ProtectedRoute({ children, allowedRoles }: ProtectedRouteProps) {
  const { isAuthenticated, user, isLoading } = useAuth()
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

  if (allowedRoles && user && !allowedRoles.includes(user.role)) {
    return (
      <div className="py-12">
        <ErrorState
          status={403}
          message={`Your account role (${user.role}) is not authorized to access this operational module.`}
        />
      </div>
    )
  }

  return <>{children}</>
}

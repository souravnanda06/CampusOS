import * as React from "react"
import { User, UserRole, isConsoleAuthorizedRole, normalizeRole } from "@/types/auth"
import { authService } from "@/services/auth/auth-service"
import { apiClient, ApiError } from "@/services/api/api-client"

interface AuthContextType {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (email: string, password: string) => Promise<User>
  logout: () => void
  hasRole: (roles: UserRole | UserRole[]) => boolean
}

const AuthContext = React.createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = React.useState<User | null>(() => authService.getCurrentUser())
  const [token, setToken] = React.useState<string | null>(() => authService.getAccessToken())
  const [isLoading, setIsLoading] = React.useState<boolean>(false)

  React.useEffect(() => {
    const unsubscribe = authService.onAuthStateChanged((newUser) => {
      setUser(newUser)
      setToken(authService.getAccessToken())
    })
    return () => unsubscribe()
  }, [])

  const login = React.useCallback(async (email: string, password: string): Promise<User> => {
    setIsLoading(true)
    try {
      const response = await apiClient.post<{ message: string; token: string; user: User }>(
        "/login",
        { email, password }
      )
      if (!isConsoleAuthorizedRole(response.user?.role)) {
        throw new ApiError(
          403,
          `Account role '${response.user?.role || "student"}' is not authorized for the CampusOS Control Plane. Please use the CampusOS mobile app.`,
          "ROLE_NOT_AUTHORIZED"
        )
      }
      authService.setSession(response.token, response.user)
      setUser(response.user)
      setToken(response.token)
      return response.user
    } finally {
      setIsLoading(false)
    }
  }, [])

  const logout = React.useCallback(() => {
    apiClient.post("/auth/logout").catch(() => undefined)
    authService.logout()
    setUser(null)
    setToken(null)
  }, [])

  const hasRole = React.useCallback(
    (roles: UserRole | UserRole[]): boolean => {
      if (!user) return false
      const allowed = (Array.isArray(roles) ? roles : [roles]).map((r) => normalizeRole(r))
      return allowed.includes(normalizeRole(user.role))
    },
    [user]
  )

  const value = React.useMemo(
    () => ({
      user,
      token,
      isAuthenticated: !!user && !!token,
      isLoading,
      login,
      logout,
      hasRole,
    }),
    [user, token, isLoading, login, logout, hasRole]
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextType {
  const context = React.useContext(AuthContext)
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider")
  }
  return context
}

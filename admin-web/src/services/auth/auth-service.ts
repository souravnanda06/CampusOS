import { User, LoginResponse } from "@/types/auth"

const TOKEN_KEY = "campusos_admin_token"
const USER_KEY = "campusos_admin_user"

type AuthListener = (user: User | null) => void

class AuthService {
  private listeners: Set<AuthListener> = new Set()

  getAccessToken(): string | null {
    try {
      return localStorage.getItem(TOKEN_KEY)
    } catch {
      return null
    }
  }

  getCurrentUser(): User | null {
    try {
      const data = localStorage.getItem(USER_KEY)
      return data ? JSON.parse(data) : null
    } catch {
      return null
    }
  }

  isAuthenticated(): boolean {
    return !!this.getAccessToken() && !!this.getCurrentUser()
  }

  setSession(token: string, user: User): void {
    try {
      localStorage.setItem(TOKEN_KEY, token)
      localStorage.setItem(USER_KEY, JSON.stringify(user))
      this.notify(user)
    } catch (err) {
      console.error("Failed to persist auth session", err)
    }
  }

  logout(): void {
    try {
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem(USER_KEY)
      this.notify(null)
    } catch (err) {
      console.error("Failed to clear auth session", err)
    }
  }

  onAuthStateChanged(listener: AuthListener): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  private notify(user: User | null): void {
    this.listeners.forEach((l) => {
      try {
        l(user)
      } catch (err) {
        console.error("Auth listener error", err)
      }
    })
  }
}

export const authService = new AuthService()

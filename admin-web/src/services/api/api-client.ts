import { authService } from "@/services/auth/auth-service"

export class ApiError extends Error {
  status: number
  resultCode?: string
  details?: unknown

  constructor(status: number, message: string, resultCode?: string, details?: unknown) {
    super(message)
    this.name = "ApiError"
    this.status = status
    this.resultCode = resultCode
    this.details = details
  }
}

interface RequestOptions extends RequestInit {
  params?: Record<string, string | number | boolean | null | undefined>
  timeoutMs?: number
}

const DEFAULT_DEPLOYED_BACKEND = "https://campusos.pythonanywhere.com"
const BASE_URL =
  import.meta.env.VITE_API_BASE_URL ||
  (import.meta.env.DEV ? "/api" : DEFAULT_DEPLOYED_BACKEND)

class ApiClient {
  private baseUrl: string

  constructor(baseUrl: string = BASE_URL) {
    this.baseUrl = baseUrl
  }

  private buildUrl(endpoint: string, params?: Record<string, string | number | boolean | null | undefined>): string {
    const cleanEndpoint = endpoint.startsWith("/") ? endpoint : `/${endpoint}`
    let url = `${this.baseUrl}${cleanEndpoint}`

    if (params) {
      const searchParams = new URLSearchParams()
      for (const [key, val] of Object.entries(params)) {
        if (val !== undefined && val !== null && val !== "") {
          searchParams.append(key, String(val))
        }
      }
      const qs = searchParams.toString()
      if (qs) {
        url += (url.includes("?") ? "&" : "?") + qs
      }
    }

    return url
  }

  async request<T>(endpoint: string, options: RequestOptions = {}): Promise<T> {
    const { params, timeoutMs = 25000, headers: customHeaders, ...fetchOpts } = options
    const url = this.buildUrl(endpoint, params)

    const headers = new Headers(customHeaders)
    const method = (fetchOpts.method || "GET").toUpperCase()
    if (method !== "GET" && method !== "HEAD") {
      if (!headers.has("Content-Type") && !(fetchOpts.body instanceof FormData)) {
        headers.set("Content-Type", "application/json")
      }
    }
    if (!headers.has("Accept")) {
      headers.set("Accept", "application/json")
    }

    // Attach Bearer token from AuthService
    const token = authService.getAccessToken()
    if (token) {
      headers.set("Authorization", `Bearer ${token}`)
    }

    // Legacy header support for existing backend route test-cases
    const user = authService.getCurrentUser()
    if (user?.id) {
      headers.set("X-User-Id", user.id)
      headers.set("X-Requester-Id", user.id)
    }

    // Abort controller for timeout
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)

    try {
      const response = await fetch(url, {
        ...fetchOpts,
        headers,
        signal: controller.signal,
      })

      clearTimeout(timer)

      // Handle HTTP status codes
      if (!response.ok) {
        let errorData: any = {}
        try {
          errorData = await response.json()
        } catch {
          errorData = { message: response.statusText || `Request failed with status ${response.status}` }
        }

        const message = errorData.message || errorData.error || `HTTP ${response.status}`
        const resultCode = errorData.resultCode

        // Handle 401 Session Expiration
        if (response.status === 401) {
          // If we had a token and got 401, session is invalid or expired
          if (authService.isAuthenticated()) {
            console.warn("[ApiClient] 401 Unauthorized encountered. Session cleared.")
            authService.logout()
          }
        }

        throw new ApiError(response.status, message, resultCode, errorData)
      }

      // Check if response has content
      const contentType = response.headers.get("content-type")
      if (contentType && contentType.includes("application/json")) {
        return (await response.json()) as T
      }

      // For 204 No Content or non-JSON responses
      return (await response.text()) as unknown as T
    } catch (err: any) {
      clearTimeout(timer)
      if (err.name === "AbortError") {
        throw new ApiError(0, "Request timed out. Please check your connection and retry.")
      }
      if (err instanceof ApiError) {
        throw err
      }
      throw new ApiError(0, err.message || "Network request failed")
    }
  }

  get<T>(endpoint: string, options?: Omit<RequestOptions, "method" | "body">): Promise<T> {
    return this.request<T>(endpoint, { ...options, method: "GET" })
  }

  post<T>(endpoint: string, data?: unknown, options?: Omit<RequestOptions, "method" | "body">): Promise<T> {
    return this.request<T>(endpoint, {
      ...options,
      method: "POST",
      body: data instanceof FormData ? data : JSON.stringify(data),
    })
  }

  put<T>(endpoint: string, data?: unknown, options?: Omit<RequestOptions, "method" | "body">): Promise<T> {
    return this.request<T>(endpoint, {
      ...options,
      method: "PUT",
      body: data instanceof FormData ? data : JSON.stringify(data),
    })
  }

  patch<T>(endpoint: string, data?: unknown, options?: Omit<RequestOptions, "method" | "body">): Promise<T> {
    return this.request<T>(endpoint, {
      ...options,
      method: "PATCH",
      body: data instanceof FormData ? data : JSON.stringify(data),
    })
  }

  delete<T>(endpoint: string, options?: Omit<RequestOptions, "method">): Promise<T> {
    return this.request<T>(endpoint, { ...options, method: "DELETE" })
  }
}

export const apiClient = new ApiClient()

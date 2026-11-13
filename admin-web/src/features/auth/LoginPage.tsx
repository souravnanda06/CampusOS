import * as React from "react"
import { useNavigate, useLocation } from "react-router-dom"
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import * as z from "zod"
import { ShieldCheck, Lock, Mail, AlertCircle, ArrowRight, Eye, EyeOff } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { useAuth } from "./AuthContext"
import { useToast } from "@/components/ui/toast"
import { CampusOSLogo } from "@/components/brand/CampusOSLogo"

const loginSchema = z.object({
  email: z.string().min(1, "Email is required").email("Please enter a valid institutional email address"),
  password: z.string().min(1, "Password is required"),
})

type LoginFormValues = z.infer<typeof loginSchema>

export function LoginPage() {
  const { login, isAuthenticated } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const { toast } = useToast()
  const [authError, setAuthError] = React.useState<string | null>(null)
  const [showPassword, setShowPassword] = React.useState(false)

  const from = (location.state as { from?: { pathname?: string } } | null)?.from?.pathname || "/"

  React.useEffect(() => {
    if (isAuthenticated) {
      navigate(from, { replace: true })
    }
  }, [isAuthenticated, navigate, from])

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: "",
      password: "",
    },
  })

  const onSubmit = async (values: LoginFormValues) => {
    setAuthError(null)
    try {
      const user = await login(values.email, values.password)
      toast({
        title: "Session Initialized",
        description: `Signed in as ${user.name} (${user.role})`,
        type: "success",
      })
      navigate(from, { replace: true })
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : "Invalid institutional credentials."
      setAuthError(msg)
    }
  }

  return (
    <div className="flex min-h-screen w-full items-center justify-center bg-background px-4 py-12">
      <div className="w-full max-w-sm space-y-6">
        {/* Brand Header */}
        <div className="flex flex-col items-center text-center space-y-2">
          <CampusOSLogo variant="mark" className="h-12 w-12 rounded-2xl shadow-md" />
          <div className="space-y-1">
            <h1 className="text-xl font-semibold tracking-tight text-foreground">
              CampusOS Control Plane
            </h1>
            <p className="text-xs text-muted-foreground">
              Unified Institutional Administration &amp; Operations
            </p>
          </div>
        </div>

        {/* Login Surface */}
        <div className="rounded-2xl border border-border/80 bg-card p-6 shadow-sm space-y-5">
          {authError && (
            <div className="flex items-start gap-2.5 rounded-lg border border-destructive/20 bg-destructive/5 p-3 text-xs text-destructive">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" />
              <span>{authError}</span>
            </div>
          )}

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">
                Institutional Email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  {...register("email")}
                  placeholder="admin@campusos.edu"
                  className="pl-9 h-9 text-xs"
                  error={!!errors.email}
                  disabled={isSubmitting}
                  autoComplete="email"
                />
              </div>
              {errors.email && (
                <p className="text-[11px] text-destructive">{errors.email.message}</p>
              )}
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-medium text-foreground">
                Password
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" />
                <Input
                  {...register("password")}
                  type={showPassword ? "text" : "password"}
                  placeholder="••••••••"
                  className="pl-9 pr-9 h-9 text-xs"
                  error={!!errors.password}
                  disabled={isSubmitting}
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  className="absolute right-2.5 top-2.5 text-muted-foreground hover:text-foreground"
                  aria-label={showPassword ? "Hide password" : "Show password"}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
              {errors.password && (
                <p className="text-[11px] text-destructive">{errors.password.message}</p>
              )}
            </div>

            <Button
              type="submit"
              className="w-full h-9 text-xs font-medium gap-1.5"
              loading={isSubmitting}
            >
              Sign In to Console
              <ArrowRight className="h-3.5 w-3.5" />
            </Button>
          </form>

          {/* Institutional Access Notice */}
          <div className="pt-2 border-t border-border/60 text-center">
            <p className="text-[11px] text-muted-foreground">
              Restricted to Dean, Admin, Warden, Faculty, Security, and Mess Staff accounts.
            </p>
          </div>
        </div>

        {/* Security Assurance footer */}
        <div className="flex items-center justify-center gap-1.5 text-[11px] text-muted-foreground">
          <ShieldCheck className="h-3.5 w-3.5 text-emerald-600 dark:text-emerald-400" />
          <span>Secured with cryptographic session tokens</span>
        </div>
      </div>
    </div>
  )
}

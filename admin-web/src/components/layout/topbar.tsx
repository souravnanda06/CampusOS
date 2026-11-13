import { useNavigate } from "react-router-dom"
import {
  Search,
  Bell,
  Sun,
  Moon,
  LogOut,
  User as UserIcon,
  Shield,
  Menu,
  Sparkles,
} from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { useAuth } from "@/features/auth/AuthContext"
import { useTheme } from "@/components/theme-provider"
import { normalizeRole } from "@/types/auth"

interface TopbarProps {
  onOpenCommandPalette: () => void
  onOpenCopilot?: () => void
  onToggleMobileSidebar?: () => void
}

const COPILOT_ROLES = ["admin", "administrator", "superadmin", "dean", "teacher", "faculty"]

export function Topbar({
  onOpenCommandPalette,
  onOpenCopilot,
  onToggleMobileSidebar,
}: TopbarProps) {
  const { user, logout } = useAuth()
  const { theme, setTheme } = useTheme()
  const navigate = useNavigate()
  const canUseCopilot = COPILOT_ROLES.includes(normalizeRole(user?.role))

  return (
    <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-border/80 bg-background/95 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/60">
      {/* Left side: Mobile menu toggle + quick search trigger */}
      <div className="flex items-center gap-3">
        {onToggleMobileSidebar && (
          <Button
            variant="ghost"
            size="icon-sm"
            className="md:hidden text-muted-foreground"
            onClick={onToggleMobileSidebar}
            aria-label="Toggle navigation menu"
          >
            <Menu className="h-4 w-4" />
          </Button>
        )}

        <button
          type="button"
          onClick={onOpenCommandPalette}
          className="flex items-center gap-2 rounded-lg border border-border/70 bg-card/60 px-3 py-1.5 text-xs text-muted-foreground shadow-sm hover:border-border hover:bg-card transition-colors w-52 sm:w-64"
        >
          <Search className="h-3.5 w-3.5 shrink-0 opacity-60" />
          <span className="truncate">Jump to or search...</span>
          <kbd className="ml-auto pointer-events-none hidden sm:inline-flex h-4 select-none items-center gap-0.5 rounded border border-border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground">
            <span className="text-[10px]">⌘</span>K
          </kbd>
        </button>
      </div>

      {/* Right side: Campus AI Copilot, Notifications, Theme toggle, Profile menu */}
      <div className="flex items-center gap-1.5">
        {canUseCopilot && onOpenCopilot && (
          <Button
            variant="outline"
            size="sm"
            onClick={onOpenCopilot}
            className="h-8 gap-1.5 text-xs border-primary/30 bg-primary/5 text-primary hover:bg-primary/10 mr-1"
          >
            <Sparkles className="h-3.5 w-3.5" />
            <span className="hidden sm:inline">Campus AI</span>
          </Button>
        )}

        <Button
          variant="ghost"
          size="icon-sm"
          onClick={() => navigate("/notifications")}
          className="relative text-muted-foreground hover:text-foreground"
          aria-label="View notifications"
        >
          <Bell className="h-4 w-4" />
        </Button>

        <Button
          variant="ghost"
          size="icon-sm"
          onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
          className="text-muted-foreground hover:text-foreground"
          aria-label="Toggle visual theme"
        >
          {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
        </Button>

        <div className="h-4 w-px bg-border/60 mx-1" />

        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="ghost"
              className="flex items-center gap-2 pl-2 pr-2.5 py-1.5 h-8 rounded-lg hover:bg-accent"
            >
              <div className="flex h-6 w-6 items-center justify-center rounded-full bg-primary/10 text-primary font-semibold text-xs border border-primary/20">
                {user?.name ? user.name.charAt(0).toUpperCase() : "U"}
              </div>
              <span className="text-xs font-medium text-foreground max-w-[120px] truncate hidden md:inline">
                {user?.name || "Administrator"}
              </span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel className="font-normal">
              <div className="flex flex-col space-y-1">
                <p className="text-xs font-semibold leading-none text-foreground">{user?.name}</p>
                <p className="text-[11px] leading-none text-muted-foreground truncate">{user?.email}</p>
                <span className="mt-1 inline-flex items-center gap-1 text-[10px] font-mono text-primary font-medium">
                  <Shield className="h-3 w-3" /> Role: {user?.role}
                </span>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem onClick={() => navigate("/people?tab=staff")}>
              <UserIcon className="h-3.5 w-3.5 mr-2 text-muted-foreground" />
              Staff Directory
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => navigate("/audit")}>
              <Shield className="h-3.5 w-3.5 mr-2 text-muted-foreground" />
              Audit Ledger
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem destructive onClick={logout}>
              <LogOut className="h-3.5 w-3.5 mr-2" />
              Sign Out
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  )
}

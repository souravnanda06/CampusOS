import * as React from "react"
import { NavLink, useLocation } from "react-router-dom"
import {
  LayoutDashboard,
  Users,
  GraduationCap,
  CalendarCheck,
  AlertCircle,
  Building2,
  Receipt,
  FileText,
  UserCheck,
  Utensils,
  Megaphone,
  Bell,
  Shield,
  KeyRound,
  History,
  ChevronLeft,
  ChevronRight,
  ShieldCheck,
} from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { CampusOSLogo } from "@/components/brand/CampusOSLogo"
import { useAuth } from "@/features/auth/AuthContext"

interface NavItem {
  title: string
  href: string
  icon: React.ElementType
  badge?: string | number
  roles?: string[]
}

interface NavSection {
  title: string
  items: NavItem[]
}

const navSections: NavSection[] = [
  {
    title: "Operations",
    items: [
      { title: "Command Center", href: "/", icon: LayoutDashboard },
      { title: "People", href: "/people", icon: Users },
      { title: "Complaints", href: "/complaints", icon: AlertCircle },
    ],
  },
  {
    title: "Academic & Campus",
    items: [
      { title: "Attendance", href: "/attendance", icon: CalendarCheck },
      { title: "Academic", href: "/academic", icon: GraduationCap },
      { title: "Hostel", href: "/hostel", icon: Building2 },
      { title: "Mess", href: "/mess", icon: Utensils },
    ],
  },
  {
    title: "Services & Finance",
    items: [
      { title: "Fees & Dues", href: "/fees", icon: Receipt },
      { title: "Documents", href: "/documents", icon: FileText },
      { title: "Visitors", href: "/visitors", icon: UserCheck },
    ],
  },
  {
    title: "Broadcasts",
    items: [
      { title: "Notices", href: "/notices", icon: Megaphone },
      { title: "Notifications", href: "/notifications", icon: Bell },
    ],
  },
  {
    title: "Security & Mesh",
    items: [
      { title: "Security Gate", href: "/security", icon: Shield },
      { title: "Passport Identity", href: "/passport", icon: KeyRound },
      { title: "Audit Trail", href: "/audit", icon: History },
    ],
  },
]

interface SidebarProps {
  collapsed: boolean
  onToggleCollapse: () => void
}

export function Sidebar({ collapsed, onToggleCollapse }: SidebarProps) {
  const location = useLocation()
  const { user } = useAuth()

  return (
    <TooltipProvider delayDuration={150}>
      <aside
        className={cn(
          "relative flex flex-col border-r border-border/80 bg-card transition-all duration-200 select-none z-30 shrink-0",
          collapsed ? "w-16" : "w-60"
        )}
      >
        {/* Brand Header */}
        <div className="flex h-14 items-center justify-between px-3.5 border-b border-border/70">
          <div className="flex items-center gap-2.5 overflow-hidden">
            <CampusOSLogo variant="mark" className="h-8 w-8 shrink-0 rounded-xl" />
            {!collapsed && (
              <div className="flex flex-col min-w-0">
                <span className="font-semibold text-xs tracking-tight text-foreground truncate">
                  CampusOS
                </span>
                <span className="text-[10px] text-muted-foreground tracking-wider uppercase font-mono">
                  Control Plane
                </span>
              </div>
            )}
          </div>

          <Button
            variant="ghost"
            size="icon-sm"
            onClick={onToggleCollapse}
            className="text-muted-foreground hover:text-foreground shrink-0 hidden md:inline-flex"
            aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          >
            {collapsed ? <ChevronRight className="h-4 w-4" /> : <ChevronLeft className="h-4 w-4" />}
          </Button>
        </div>

        {/* Navigation Sections */}
        <div className="flex-1 overflow-y-auto px-2 py-3 space-y-4">
          {navSections.map((section) => (
            <div key={section.title} className="space-y-1">
              {!collapsed && (
                <p className="px-2.5 text-[10px] font-semibold text-muted-foreground tracking-wider uppercase">
                  {section.title}
                </p>
              )}
              {collapsed && <div className="h-px bg-border/40 mx-2 my-2" />}

              {section.items.map((item) => {
                const Icon = item.icon
                const isActive =
                  item.href === "/"
                    ? location.pathname === "/"
                    : location.pathname.startsWith(item.href)

                const linkContent = (
                  <NavLink
                    to={item.href}
                    className={cn(
                      "flex items-center gap-2.5 rounded-lg px-2.5 py-1.5 text-xs font-medium transition-colors relative group",
                      isActive
                        ? "bg-accent text-accent-foreground font-semibold"
                        : "text-muted-foreground hover:bg-accent/60 hover:text-foreground",
                      collapsed && "justify-center px-0 w-10 h-10 mx-auto"
                    )}
                  >
                    {isActive && (
                      <span className="absolute left-0 top-1.5 bottom-1.5 w-1 rounded-r-md bg-primary" />
                    )}
                    <Icon
                      className={cn(
                        "h-4 w-4 shrink-0 transition-colors",
                        isActive ? "text-primary dark:text-cyan-400" : "text-muted-foreground group-hover:text-foreground"
                      )}
                    />
                    {!collapsed && <span className="truncate">{item.title}</span>}
                    {!collapsed && item.badge && (
                      <span className="ml-auto rounded-full bg-primary/10 px-1.5 py-0.5 text-[10px] font-mono text-primary">
                        {item.badge}
                      </span>
                    )}
                  </NavLink>
                )

                if (collapsed) {
                  return (
                    <Tooltip key={item.href}>
                      <TooltipTrigger asChild>{linkContent}</TooltipTrigger>
                      <TooltipContent side="right" className="font-medium text-xs">
                        {item.title}
                      </TooltipContent>
                    </Tooltip>
                  )
                }

                return <div key={item.href}>{linkContent}</div>
              })}
            </div>
          ))}
        </div>

        {/* Institutional Authority Tag */}
        <div className="p-3 border-t border-border/70 text-[11px] text-muted-foreground">
          {!collapsed ? (
            <div className="flex items-center gap-2">
              <ShieldCheck className="h-4 w-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
              <div className="truncate">
                <p className="font-medium text-foreground truncate text-[11px]">Authorized Console</p>
                <p className="text-[10px] text-muted-foreground truncate">{user?.role || "Staff"} Session</p>
              </div>
            </div>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <div className="flex justify-center">
                  <ShieldCheck className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
                </div>
              </TooltipTrigger>
              <TooltipContent side="right">Authorized {user?.role || "Staff"} Console</TooltipContent>
            </Tooltip>
          )}
        </div>
      </aside>
    </TooltipProvider>
  )
}

import * as React from "react"
import { NavLink, useLocation } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
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
  CalendarClock,
  Radio,
  Search,
  Briefcase,
} from "lucide-react"
import { cn } from "@/lib/utils"
import { Button } from "@/components/ui/button"
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip"
import { CampusOSLogo } from "@/components/brand/CampusOSLogo"
import { useAuth } from "@/features/auth/AuthContext"
import { normalizeRole } from "@/types/auth"
import { dashboardApi } from "@/features/dashboard/api/dashboard-api"

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

const ADMIN_ROLES = ["admin", "administrator", "superadmin", "dean", "staff"]
const WARDEN_ADMIN = [...ADMIN_ROLES, "warden"]
const ACADEMIC_ROLES = [...ADMIN_ROLES, "teacher", "faculty"]
const MESS_ROLES = [...ADMIN_ROLES, "warden", "mess_staff", "mess"]
const SECURITY_ROLES = [...ADMIN_ROLES, "warden", "security", "guard", "security_guard"]

const navSections: NavSection[] = [
  {
    title: "Operations",
    items: [
      { title: "Command Center", href: "/", icon: LayoutDashboard, roles: ADMIN_ROLES },
      { title: "People & Roles", href: "/people", icon: Users, roles: ADMIN_ROLES },
      { title: "Complaints", href: "/complaints", icon: AlertCircle, roles: ADMIN_ROLES },
      { title: "Leave Approvals", href: "/leaves", icon: CalendarClock, roles: WARDEN_ADMIN },
    ],
  },
  {
    title: "Academic & Campus",
    items: [
      { title: "Attendance", href: "/attendance", icon: CalendarCheck, roles: ACADEMIC_ROLES },
      { title: "Academic", href: "/academic", icon: GraduationCap, roles: ACADEMIC_ROLES },
      { title: "Placement (TPO)", href: "/placements", icon: Briefcase, roles: ADMIN_ROLES },
      { title: "Hostel", href: "/hostel", icon: Building2, roles: WARDEN_ADMIN },
      { title: "Mess", href: "/mess", icon: Utensils, roles: MESS_ROLES },
    ],
  },
  {
    title: "Services & Finance",
    items: [
      { title: "Fees & Dues", href: "/fees", icon: Receipt, roles: WARDEN_ADMIN },
      { title: "Documents", href: "/documents", icon: FileText, roles: ADMIN_ROLES },
      { title: "Visitors", href: "/visitors", icon: UserCheck, roles: SECURITY_ROLES },
    ],
  },
  {
    title: "Broadcasts & Mesh",
    items: [
      { title: "Notices", href: "/notices", icon: Megaphone, roles: ACADEMIC_ROLES },
      { title: "Notifications", href: "/notifications", icon: Bell },
      { title: "Mesh & Moderation", href: "/mesh", icon: Radio, roles: SECURITY_ROLES },
    ],
  },
  {
    title: "Security & Governance",
    items: [
      { title: "Security Gate", href: "/security", icon: Shield, roles: SECURITY_ROLES },
      { title: "Passport Identity", href: "/passport", icon: KeyRound, roles: [...ADMIN_ROLES, "warden", "teacher"] },
      { title: "Audit Ledger", href: "/audit", icon: History, roles: [...ADMIN_ROLES, "warden", "security", "guard", "security_guard"] },
      { title: "Global Search", href: "/search", icon: Search },
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
  const userRole = normalizeRole(user?.role)

  const isAdmin = ADMIN_ROLES.includes(userRole)
  const { data: summary } = useQuery({
    queryKey: ["admin", "dashboard", "summary"],
    queryFn: dashboardApi.getSummary,
    staleTime: 15000,
    refetchInterval: 30000,
    enabled: isAdmin,
  })

  const visibleSections = React.useMemo(() => {
    return navSections
      .map((sec) => ({
        ...sec,
        items: sec.items
          .filter((item) => !item.roles || item.roles.includes(userRole))
          .map((item) => {
            if (item.href === "/people" && (summary?.pendingStudentApprovals || 0) > 0) {
              return { ...item, badge: summary?.pendingStudentApprovals }
            }
            if (item.href === "/complaints" && (summary?.pendingComplaints || 0) > 0) {
              return { ...item, badge: summary?.pendingComplaints }
            }
            return item
          }),
      }))
      .filter((sec) => sec.items.length > 0)
  }, [userRole, summary])

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
          {visibleSections.map((section) => (
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
                    {collapsed && item.badge && (
                      <span className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-amber-500 ring-2 ring-card" />
                    )}
                    {!collapsed && <span className="truncate">{item.title}</span>}
                    {!collapsed && item.badge && (
                      <span
                        className={cn(
                          "ml-auto rounded-full px-1.5 py-0.5 text-[10px] font-mono",
                          item.href === "/people"
                            ? "bg-amber-500/15 text-amber-600 dark:text-amber-400 font-bold border border-amber-500/30"
                            : "bg-primary/10 text-primary font-semibold"
                        )}
                      >
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
                        {item.title} {item.badge ? `(${item.badge} pending)` : ""}
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
                <p className="text-[10px] text-muted-foreground truncate capitalize">{user?.role || "Staff"} Session</p>
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

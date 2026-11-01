import * as React from "react"
import { useNavigate } from "react-router-dom"
import { Command as CommandPrimitive } from "cmdk"
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
  Search,
  ExternalLink,
} from "lucide-react"
import { Dialog, DialogContent } from "@/components/ui/dialog"
import { cn } from "@/lib/utils"
import { useAuth } from "@/features/auth/AuthContext"

interface CommandPaletteProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [searchQuery, setSearchQuery] = React.useState("")

  React.useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        onOpenChange(!open)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [open, onOpenChange])

  const runCommand = React.useCallback(
    (command: () => void) => {
      onOpenChange(false)
      command()
    },
    [onOpenChange]
  )

  const navItems = [
    { title: "Command Center", icon: LayoutDashboard, path: "/", section: "Core Operations" },
    { title: "People Management", icon: Users, path: "/people", section: "Core Operations" },
    { title: "Complaints Desk", icon: AlertCircle, path: "/complaints", section: "Core Operations" },
    { title: "Attendance Control", icon: CalendarCheck, path: "/attendance", section: "Academic" },
    { title: "Academic Updates", icon: GraduationCap, path: "/academic", section: "Academic" },
    { title: "Notices Publishing", icon: Megaphone, path: "/notices", section: "Communications" },
    { title: "Push Notifications", icon: Bell, path: "/notifications", section: "Communications" },
    { title: "Hostel Operations", icon: Building2, path: "/hostel", section: "Campus Facilities" },
    { title: "Mess Management", icon: Utensils, path: "/mess", section: "Campus Facilities" },
    { title: "Visitor Gate Pass", icon: UserCheck, path: "/visitors", section: "Campus Facilities" },
    { title: "Fees & Dues Accounting", icon: Receipt, path: "/fees", section: "Administration" },
    { title: "Document Requests", icon: FileText, path: "/documents", section: "Administration" },
    { title: "Security Gate Logs", icon: Shield, path: "/security", section: "Security & Identity" },
    { title: "Passport Identity Mesh", icon: KeyRound, path: "/passport", section: "Security & Identity" },
    { title: "Audit Trail", icon: History, path: "/audit", section: "Security & Identity" },
  ]

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="p-0 overflow-hidden max-w-xl border-border bg-popover shadow-2xl rounded-2xl">
        <CommandPrimitive className="flex flex-col w-full h-full max-h-[460px] overflow-hidden">
          <div className="flex items-center px-3.5 border-b border-border/80">
            <Search className="w-4 h-4 mr-2.5 text-muted-foreground shrink-0" />
            <CommandPrimitive.Input
              value={searchQuery}
              onValueChange={setSearchQuery}
              placeholder="Search operational modules, people, or commands... (Cmd+K)"
              className="w-full py-3.5 text-sm bg-transparent outline-none placeholder:text-muted-foreground text-foreground"
            />
          </div>

          <CommandPrimitive.List className="overflow-y-auto max-h-[380px] p-2 space-y-1">
            <CommandPrimitive.Empty className="py-8 text-xs text-center text-muted-foreground">
              No matching control plane modules found.
            </CommandPrimitive.Empty>

            {/* Core Operations Group */}
            <CommandPrimitive.Group
              heading="Operational Modules"
              className="text-[11px] font-semibold text-muted-foreground uppercase px-2 py-1.5"
            >
              {navItems.map((item) => {
                const Icon = item.icon
                return (
                  <CommandPrimitive.Item
                    key={item.path}
                    value={item.title}
                    onSelect={() => runCommand(() => navigate(item.path))}
                    className="flex items-center gap-2.5 px-2.5 py-2 text-xs rounded-lg cursor-pointer text-foreground hover:bg-accent focus:bg-accent select-none transition-colors"
                  >
                    <Icon className="w-4 h-4 text-muted-foreground shrink-0" />
                    <span className="flex-1 font-medium">{item.title}</span>
                    <span className="text-[10px] text-muted-foreground font-mono">{item.path}</span>
                  </CommandPrimitive.Item>
                )
              })}
            </CommandPrimitive.Group>
          </CommandPrimitive.List>

          <div className="flex items-center justify-between px-3 py-2 border-t border-border/60 bg-muted/30 text-[11px] text-muted-foreground">
            <span>Navigation: <kbd className="px-1 py-0.5 rounded bg-muted font-mono text-[10px]">↑</kbd> <kbd className="px-1 py-0.5 rounded bg-muted font-mono text-[10px]">↓</kbd></span>
            <span>Select: <kbd className="px-1.5 py-0.5 rounded bg-muted font-mono text-[10px]">Enter</kbd></span>
            <span>Close: <kbd className="px-1.5 py-0.5 rounded bg-muted font-mono text-[10px]">Esc</kbd></span>
          </div>
        </CommandPrimitive>
      </DialogContent>
    </Dialog>
  )
}

import * as React from "react"
import { useNavigate } from "react-router-dom"
import { useQuery } from "@tanstack/react-query"
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
  CalendarClock,
  Radio,
  ArrowRight,
} from "lucide-react"
import { Dialog, DialogContent } from "@/components/ui/dialog"
import { Badge } from "@/components/ui/badge"
import { searchApi } from "@/features/search/api/search-api"

interface CommandPaletteProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CommandPalette({ open, onOpenChange }: CommandPaletteProps) {
  const navigate = useNavigate()
  const [searchQuery, setSearchQuery] = React.useState("")
  const [debouncedQuery, setDebouncedQuery] = React.useState("")

  React.useEffect(() => {
    const t = setTimeout(() => setDebouncedQuery(searchQuery.trim()), 200)
    return () => clearTimeout(t)
  }, [searchQuery])

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

  const { data: liveSearch } = useQuery({
    queryKey: ["command-palette-search", debouncedQuery],
    queryFn: () => searchApi.search(debouncedQuery),
    enabled: open && debouncedQuery.length >= 2,
    staleTime: 10000,
  })

  const runCommand = React.useCallback(
    (command: () => void) => {
      onOpenChange(false)
      setSearchQuery("")
      command()
    },
    [onOpenChange]
  )

  const navItems = [
    { title: "Command Center", icon: LayoutDashboard, path: "/" },
    { title: "People & Role Management", icon: Users, path: "/people" },
    { title: "Complaints Desk & SLA", icon: AlertCircle, path: "/complaints" },
    { title: "Leave & Gate Approvals", icon: CalendarClock, path: "/leaves" },
    { title: "Attendance Control", icon: CalendarCheck, path: "/attendance" },
    { title: "Academic Updates", icon: GraduationCap, path: "/academic" },
    { title: "Notices Publishing", icon: Megaphone, path: "/notices" },
    { title: "Push Notifications", icon: Bell, path: "/notifications" },
    { title: "Campus Mesh & Emergency", icon: Radio, path: "/mesh" },
    { title: "Hostel & Asset Operations", icon: Building2, path: "/hostel" },
    { title: "Mess & Feedback Analytics", icon: Utensils, path: "/mess" },
    { title: "Visitor Gate Pass", icon: UserCheck, path: "/visitors" },
    { title: "Fees & Dues Accounting", icon: Receipt, path: "/fees" },
    { title: "Document Requests", icon: FileText, path: "/documents" },
    { title: "Security Gate Logs", icon: Shield, path: "/security" },
    { title: "Passport Identity Mesh", icon: KeyRound, path: "/passport" },
    { title: "Audit Ledger", icon: History, path: "/audit" },
    { title: "Global Institutional Search", icon: Search, path: "/search" },
  ]

  const resolveResultPath = (category: string, id: string) => {
    switch (category.toLowerCase()) {
      case "complaint":
        return `/complaints/${id}`
      case "document":
        return "/documents"
      case "fee record":
      case "fee":
        return "/fees"
      case "hostel & room":
      case "hostel":
        return "/hostel"
      case "visitor pass":
      case "visitor":
        return "/visitors"
      case "class update":
      case "academic":
        return "/academic"
      default:
        return "/notices"
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="p-0 overflow-hidden max-w-xl border-border bg-popover shadow-2xl rounded-2xl">
        <CommandPrimitive shouldFilter={debouncedQuery.length < 2} className="flex flex-col w-full h-full max-h-[480px] overflow-hidden">
          <div className="flex items-center px-3.5 border-b border-border/80">
            <Search className="w-4 h-4 mr-2.5 text-muted-foreground shrink-0" />
            <CommandPrimitive.Input
              value={searchQuery}
              onValueChange={setSearchQuery}
              placeholder="Jump to module or search records... (Cmd+K)"
              className="w-full py-3.5 text-sm bg-transparent outline-none placeholder:text-muted-foreground text-foreground"
            />
          </div>

          <CommandPrimitive.List className="overflow-y-auto max-h-[380px] p-2 space-y-2">
            <CommandPrimitive.Empty className="py-6 text-xs text-center text-muted-foreground">
              No matching control plane modules found.
            </CommandPrimitive.Empty>

            {debouncedQuery.length >= 2 && (
              <CommandPrimitive.Group
                heading="Global Search"
                className="text-[11px] font-semibold text-muted-foreground uppercase px-2 py-1"
              >
                <CommandPrimitive.Item
                  value={`search-all-${debouncedQuery}`}
                  onSelect={() => runCommand(() => navigate(`/search?q=${encodeURIComponent(debouncedQuery)}`))}
                  className="flex items-center gap-2.5 px-2.5 py-2 text-xs rounded-lg cursor-pointer text-primary hover:bg-accent focus:bg-accent select-none"
                >
                  <Search className="w-4 h-4 shrink-0" />
                  <span className="flex-1 font-medium">
                    Search all campus records for "{debouncedQuery}"
                  </span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </CommandPrimitive.Item>

                {liveSearch?.results?.slice(0, 6).map((res) => (
                  <CommandPrimitive.Item
                    key={`${res.category}-${res.id}`}
                    value={`${res.category} ${res.title} ${res.subtitle}`}
                    onSelect={() => runCommand(() => navigate(resolveResultPath(res.category, res.id)))}
                    className="flex items-center gap-2.5 px-2.5 py-2 text-xs rounded-lg cursor-pointer text-foreground hover:bg-accent focus:bg-accent select-none"
                  >
                    <Badge variant="secondary" className="text-[9px] font-mono shrink-0">
                      {res.category}
                    </Badge>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium truncate">{res.title}</p>
                      <p className="text-[10px] text-muted-foreground truncate">{res.subtitle}</p>
                    </div>
                  </CommandPrimitive.Item>
                ))}
              </CommandPrimitive.Group>
            )}

            <CommandPrimitive.Group
              heading="Operational Modules"
              className="text-[11px] font-semibold text-muted-foreground uppercase px-2 py-1"
            >
              {navItems
                .filter((it) =>
                  debouncedQuery.length < 2
                    ? true
                    : it.title.toLowerCase().includes(debouncedQuery.toLowerCase())
                )
                .map((item) => {
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

import * as React from "react"
import { useMutation, useQueryClient } from "@tanstack/react-query"
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { useToast } from "@/components/ui/toast"
import { messApi, MessMealItem } from "../api/mess-api"

interface CreateMenuDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CreateMenuDialog({ open, onOpenChange }: CreateMenuDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [menuDate, setMenuDate] = React.useState<string>(
    new Date(Date.now() + 24 * 3600 * 1000).toISOString().split("T")[0]
  )

  const [breakfastItems, setBreakfastItems] = React.useState("Idli, Sambar, Coconut Chutney, Tea/Coffee")
  const [lunchItems, setLunchItems] = React.useState("Rice, Dal Makhani, Paneer Butter Masala, Roti, Salad")
  const [snacksItems, setSnacksItems] = React.useState("Veg Samosa, Green Chutney, Masala Chai")
  const [dinnerItems, setDinnerItems] = React.useState("Jeera Rice, Yellow Dal Tadka, Mix Veg Curry, Chapati, Kheer")

  const mutation = useMutation({
    mutationFn: (publish: boolean) => {
      const meals: MessMealItem[] = [
        {
          meal_type: "BREAKFAST",
          title: "Executive Breakfast",
          items: breakfastItems.split(",").map((s) => s.trim()).filter(Boolean),
          availability: "AVAILABLE",
          display_order: 1,
        },
        {
          meal_type: "LUNCH",
          title: "Full Course Lunch",
          items: lunchItems.split(",").map((s) => s.trim()).filter(Boolean),
          availability: "AVAILABLE",
          display_order: 2,
        },
        {
          meal_type: "SNACKS",
          title: "Evening Refreshments",
          items: snacksItems.split(",").map((s) => s.trim()).filter(Boolean),
          availability: "AVAILABLE",
          display_order: 3,
        },
        {
          meal_type: "DINNER",
          title: "Institutional Dinner",
          items: dinnerItems.split(",").map((s) => s.trim()).filter(Boolean),
          availability: "AVAILABLE",
          display_order: 4,
        },
      ]
      return messApi.createMenu(menuDate, meals, publish ? "PUBLISHED" : "DRAFT")
    },
    onSuccess: (data) => {
      toast({
        title: "Mess Menu Saved",
        description: `Daily menu for ${data.menu_date} set to ${data.status}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["mess"] })
      onOpenChange(false)
    },
    onError: (err: any) => {
      toast({
        title: "Failed to Save Menu",
        description: err.message || "Failed to create daily mess menu",
        type: "error",
      })
    },
  })

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Author Institutional Daily Mess Menu</DialogTitle>
          <DialogDescription>
            Configure the 4-meal daily catering schedule for campus dining halls.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-3.5 py-2 text-xs">
          <div className="space-y-1">
            <label className="text-xs font-medium text-foreground">Menu Date</label>
            <Input
              type="date"
              value={menuDate}
              onChange={(e) => setMenuDate(e.target.value)}
              className="h-8 text-xs w-48"
            />
          </div>

          <div className="space-y-3 pt-1">
            <div className="space-y-1">
              <label className="text-xs font-semibold text-foreground">Breakfast Items (Comma-separated)</label>
              <Input
                value={breakfastItems}
                onChange={(e) => setBreakfastItems(e.target.value)}
                className="h-8 text-xs"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-foreground">Lunch Items (Comma-separated)</label>
              <Input
                value={lunchItems}
                onChange={(e) => setLunchItems(e.target.value)}
                className="h-8 text-xs"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-foreground">Evening Snacks (Comma-separated)</label>
              <Input
                value={snacksItems}
                onChange={(e) => setSnacksItems(e.target.value)}
                className="h-8 text-xs"
              />
            </div>

            <div className="space-y-1">
              <label className="text-xs font-semibold text-foreground">Dinner Items (Comma-separated)</label>
              <Input
                value={dinnerItems}
                onChange={(e) => setDinnerItems(e.target.value)}
                className="h-8 text-xs"
              />
            </div>
          </div>
        </div>

        <DialogFooter className="gap-2 pt-2">
          <Button variant="outline" size="sm" onClick={() => onOpenChange(false)}>
            Cancel
          </Button>
          <Button
            variant="secondary"
            size="sm"
            loading={mutation.isPending}
            onClick={() => mutation.mutate(false)}
          >
            Save as Draft
          </Button>
          <Button
            size="sm"
            loading={mutation.isPending}
            onClick={() => mutation.mutate(true)}
          >
            Publish Menu
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

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
import { messApi, MessMealItem, MessMenuRecord } from "../api/mess-api"

interface CreateMenuDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  menuToEdit?: MessMenuRecord | null
}

const DEFAULT_MEAL_ITEMS = {
  BREAKFAST: "Idli, Sambar, Coconut Chutney, Tea/Coffee",
  LUNCH: "Rice, Dal Makhani, Paneer Butter Masala, Roti, Salad",
  SNACKS: "Veg Samosa, Green Chutney, Masala Chai",
  DINNER: "Jeera Rice, Yellow Dal Tadka, Mix Veg Curry, Chapati, Kheer",
}

const getTomorrowIsoDate = () => {
  const d = new Date()
  d.setDate(d.getDate() + 1)
  return d.toISOString().split("T")[0]
}

export function CreateMenuDialog({ open, onOpenChange, menuToEdit }: CreateMenuDialogProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  const [menuDate, setMenuDate] = React.useState<string>(getTomorrowIsoDate)
  const [breakfastItems, setBreakfastItems] = React.useState(DEFAULT_MEAL_ITEMS.BREAKFAST)
  const [lunchItems, setLunchItems] = React.useState(DEFAULT_MEAL_ITEMS.LUNCH)
  const [snacksItems, setSnacksItems] = React.useState(DEFAULT_MEAL_ITEMS.SNACKS)
  const [dinnerItems, setDinnerItems] = React.useState(DEFAULT_MEAL_ITEMS.DINNER)

  React.useEffect(() => {
    if (!open) return
    if (menuToEdit) {
      setMenuDate(menuToEdit.menuDate)
      const findItems = (type: string, fallback: string) => {
        const meal = menuToEdit.meals?.find((m) => m.mealType === type)
        return meal && meal.items.length > 0 ? meal.items.join(", ") : fallback
      }
      setBreakfastItems(findItems("BREAKFAST", DEFAULT_MEAL_ITEMS.BREAKFAST))
      setLunchItems(findItems("LUNCH", DEFAULT_MEAL_ITEMS.LUNCH))
      setSnacksItems(findItems("SNACKS", DEFAULT_MEAL_ITEMS.SNACKS))
      setDinnerItems(findItems("DINNER", DEFAULT_MEAL_ITEMS.DINNER))
    } else {
      setMenuDate(getTomorrowIsoDate())
      setBreakfastItems(DEFAULT_MEAL_ITEMS.BREAKFAST)
      setLunchItems(DEFAULT_MEAL_ITEMS.LUNCH)
      setSnacksItems(DEFAULT_MEAL_ITEMS.SNACKS)
      setDinnerItems(DEFAULT_MEAL_ITEMS.DINNER)
    }
  }, [open, menuToEdit])

  const buildMeals = (): MessMealItem[] => [
    {
      mealType: "BREAKFAST",
      title: "Executive Breakfast",
      items: breakfastItems.split(",").map((s) => s.trim()).filter(Boolean),
      availability: "AVAILABLE",
      displayOrder: 1,
    },
    {
      mealType: "LUNCH",
      title: "Full Course Lunch",
      items: lunchItems.split(",").map((s) => s.trim()).filter(Boolean),
      availability: "AVAILABLE",
      displayOrder: 2,
    },
    {
      mealType: "SNACKS",
      title: "Evening Refreshments",
      items: snacksItems.split(",").map((s) => s.trim()).filter(Boolean),
      availability: "AVAILABLE",
      displayOrder: 3,
    },
    {
      mealType: "DINNER",
      title: "Institutional Dinner",
      items: dinnerItems.split(",").map((s) => s.trim()).filter(Boolean),
      availability: "AVAILABLE",
      displayOrder: 4,
    },
  ]

  const mutation = useMutation({
    mutationFn: (publish: boolean) => {
      const meals = buildMeals()
      if (menuToEdit) {
        return messApi.updateMenu(menuToEdit.id, {
          menuDate,
          status: publish ? "PUBLISHED" : menuToEdit.status,
          meals,
        })
      }
      return messApi.createMenu(menuDate, meals, publish ? "PUBLISHED" : "DRAFT")
    },
    onSuccess: (data) => {
      toast({
        title: menuToEdit ? "Mess Menu Updated" : "Mess Menu Saved",
        description: `Daily menu for ${data.menuDate} is ${data.status}.`,
        type: "success",
      })
      queryClient.invalidateQueries({ queryKey: ["mess"] })
      onOpenChange(false)
    },
    onError: (err: Error) => {
      toast({
        title: "Failed to Save Menu",
        description: err.message || "Failed to save daily mess menu",
        type: "error",
      })
    },
  })

  const isEditingPublished = menuToEdit?.status === "PUBLISHED"

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>
            {menuToEdit ? "Edit Daily Mess Menu" : "Author Institutional Daily Mess Menu"}
          </DialogTitle>
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
          {!isEditingPublished && (
            <Button
              variant="secondary"
              size="sm"
              loading={mutation.isPending}
              onClick={() => mutation.mutate(false)}
            >
              {menuToEdit ? "Save Changes" : "Save as Draft"}
            </Button>
          )}
          <Button
            size="sm"
            loading={mutation.isPending}
            onClick={() => mutation.mutate(true)}
          >
            {isEditingPublished ? "Update Published Menu" : "Publish Menu"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

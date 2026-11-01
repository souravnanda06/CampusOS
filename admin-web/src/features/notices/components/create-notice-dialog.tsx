import * as React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { noticesApi, type CreateNoticePayload, type NoticeCategory, type NoticePriority, type NoticeTargetType, type NoticeStatus } from '../api/notices-api';
import { useToast } from '@/components/ui/toast';
import { Megaphone, AlertCircle } from 'lucide-react';

const noticeSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters'),
  body: z.string().min(5, 'Notice body must be at least 5 characters'),
  category: z.enum(['GENERAL', 'ACADEMIC', 'EXAM', 'HOSTEL', 'MESS', 'SECURITY', 'EVENT', 'FEE', 'OTHER'] as const),
  priority: z.enum(['NORMAL', 'HIGH', 'URGENT'] as const),
  target_type: z.enum(['ALL', 'BRANCH', 'YEAR', 'STUDENT'] as const),
  target_value: z.string().optional(),
  expires_at: z.string().optional(),
  status: z.enum(['PUBLISHED', 'DRAFT'] as const),
}).refine(data => {
  if (['BRANCH', 'YEAR', 'STUDENT'].includes(data.target_type) && !data.target_value?.trim()) {
    return false;
  }
  return true;
}, {
  message: 'Target value is required when targeting by Branch, Year, or Student',
  path: ['target_value'],
});

type FormValues = z.infer<typeof noticeSchema>;

interface CreateNoticeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}

export const CreateNoticeDialog: React.FC<CreateNoticeDialogProps> = ({
  open,
  onOpenChange,
  onSuccess,
}) => {
  const { addToast } = useToast();
  const [submitting, setSubmitting] = React.useState(false);
  const [formError, setFormError] = React.useState<string | null>(null);

  const {
    register,
    handleSubmit,
    watch,
    reset,
    formState: { errors },
  } = useForm<FormValues>({
    resolver: zodResolver(noticeSchema),
    defaultValues: {
      title: '',
      body: '',
      category: 'GENERAL',
      priority: 'NORMAL',
      target_type: 'ALL',
      target_value: '',
      expires_at: '',
      status: 'PUBLISHED',
    },
  });

  const selectedTargetType = watch('target_type');

  const onSubmit = async (data: FormValues) => {
    setSubmitting(true);
    setFormError(null);

    try {
      const payload: CreateNoticePayload = {
        title: data.title.trim(),
        body: data.body.trim(),
        category: data.category as NoticeCategory,
        priority: data.priority as NoticePriority,
        target_type: data.target_type as NoticeTargetType,
        target_value: data.target_value?.trim() || undefined,
        expires_at: data.expires_at || undefined,
        status: data.status as NoticeStatus,
      };

      await noticesApi.createNotice(payload);
      addToast({
        type: 'success',
        title: 'Notice Created',
        message: data.status === 'PUBLISHED' ? 'Notice published and queued for push notification dispatch.' : 'Notice saved as draft.',
      });
      reset();
      onOpenChange(false);
      onSuccess();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to publish notice';
      setFormError(msg);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[580px]">
        <DialogHeader>
          <div className="flex items-center gap-2 text-primary">
            <Megaphone className="h-5 w-5" />
            <DialogTitle>Broadcast Notice</DialogTitle>
          </div>
          <DialogDescription>
            Publish an institutional broadcast to students, specific cohorts, or departments.
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 py-2">
          {formError && (
            <div className="flex items-center gap-2 rounded-md bg-destructive/10 p-3 text-xs text-destructive">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>{formError}</span>
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Notice Title *
            </label>
            <Input
              placeholder="e.g., Mid-Term Examination Schedule Announcement"
              {...register('title')}
            />
            {errors.title && (
              <p className="text-xs text-destructive">{errors.title.message}</p>
            )}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Category
              </label>
              <select
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
                {...register('category')}
              >
                <option value="GENERAL">General</option>
                <option value="ACADEMIC">Academic</option>
                <option value="EXAM">Exam</option>
                <option value="HOSTEL">Hostel</option>
                <option value="MESS">Mess</option>
                <option value="SECURITY">Security</option>
                <option value="EVENT">Event</option>
                <option value="FEE">Fee</option>
                <option value="OTHER">Other</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Priority
              </label>
              <select
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
                {...register('priority')}
              >
                <option value="NORMAL">Normal</option>
                <option value="HIGH">High</option>
                <option value="URGENT">Urgent (Immediate Push)</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Target Audience
              </label>
              <select
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
                {...register('target_type')}
              >
                <option value="ALL">All Students (Campus-wide)</option>
                <option value="BRANCH">Specific Branch</option>
                <option value="YEAR">Specific Academic Year</option>
                <option value="STUDENT">Single Student ID</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Status
              </label>
              <select
                className="w-full rounded-md border border-input bg-background px-3 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
                {...register('status')}
              >
                <option value="PUBLISHED">Publish Immediately</option>
                <option value="DRAFT">Save as Draft</option>
              </select>
            </div>
          </div>

          {selectedTargetType !== 'ALL' && (
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                {selectedTargetType === 'BRANCH' && 'Branch Code (e.g. CSE, ECE, MECH)'}
                {selectedTargetType === 'YEAR' && 'Academic Year (e.g. 1, 2, 3, 4)'}
                {selectedTargetType === 'STUDENT' && 'Student User ID (UUID)'}
                {' *'}
              </label>
              <Input
                placeholder={
                  selectedTargetType === 'BRANCH'
                    ? 'CSE'
                    : selectedTargetType === 'YEAR'
                    ? '3'
                    : 'User UUID'
                }
                {...register('target_value')}
              />
              {errors.target_value && (
                <p className="text-xs text-destructive">{errors.target_value.message}</p>
              )}
            </div>
          )}

          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Notice Content *
            </label>
            <textarea
              rows={4}
              className="w-full rounded-md border border-input bg-background p-3 text-xs focus:outline-none focus:ring-1 focus:ring-ring"
              placeholder="Enter full notice body text. Plain text or markdown supported..."
              {...register('body')}
            />
            {errors.body && (
              <p className="text-xs text-destructive">{errors.body.message}</p>
            )}
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Expiry Date (Optional)
            </label>
            <Input
              type="date"
              {...register('expires_at')}
            />
          </div>

          <DialogFooter className="pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={submitting}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Broadcasting...' : 'Broadcast Notice'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

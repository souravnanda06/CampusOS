import * as React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useMutation, useQueryClient } from '@tanstack/react-query';
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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import {
  noticesApi,
  type CreateNoticePayload,
  type Notice,
  type NoticeCategory,
  type NoticePriority,
  type NoticeTargetType,
  type NoticeStatus,
} from '../api/notices-api';
import { useToast } from '@/components/ui/toast';
import { Megaphone, AlertCircle } from 'lucide-react';

const noticeSchema = z
  .object({
    title: z.string().min(3, 'Title must be at least 3 characters'),
    body: z.string().min(5, 'Notice body must be at least 5 characters'),
    category: z.enum([
      'GENERAL',
      'ACADEMIC',
      'EXAM',
      'HOSTEL',
      'MESS',
      'SECURITY',
      'EVENT',
      'FEE',
      'OTHER',
    ] as const),
    priority: z.enum(['NORMAL', 'HIGH', 'URGENT'] as const),
    target_type: z.enum(['ALL', 'BRANCH', 'YEAR', 'STUDENT'] as const),
    target_value: z.string().optional(),
    expires_at: z.string().optional(),
    status: z.enum(['PUBLISHED', 'DRAFT'] as const),
  })
  .refine(
    (data) => {
      if (['BRANCH', 'YEAR', 'STUDENT'].includes(data.target_type) && !data.target_value?.trim()) {
        return false;
      }
      return true;
    },
    {
      message: 'Target value is required when targeting by Branch, Year, or Student',
      path: ['target_value'],
    }
  );

type FormValues = z.infer<typeof noticeSchema>;

interface CreateNoticeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
  noticeToEdit?: Notice | null;
}

export const CreateNoticeDialog: React.FC<CreateNoticeDialogProps> = ({
  open,
  onOpenChange,
  onSuccess,
  noticeToEdit,
}) => {
  const { addToast } = useToast();
  const queryClient = useQueryClient();

  const {
    register,
    handleSubmit,
    watch,
    setValue,
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

  React.useEffect(() => {
    if (!open) return;
    if (noticeToEdit) {
      reset({
        title: noticeToEdit.title,
        body: noticeToEdit.body || noticeToEdit.content || '',
        category: noticeToEdit.category,
        priority: noticeToEdit.priority,
        target_type: noticeToEdit.targetType,
        target_value: noticeToEdit.targetValue || '',
        expires_at: noticeToEdit.expiresAt ? noticeToEdit.expiresAt.slice(0, 10) : '',
        status: noticeToEdit.status === 'DRAFT' ? 'DRAFT' : 'PUBLISHED',
      });
    } else {
      reset({
        title: '',
        body: '',
        category: 'GENERAL',
        priority: 'NORMAL',
        target_type: 'ALL',
        target_value: '',
        expires_at: '',
        status: 'PUBLISHED',
      });
    }
  }, [open, noticeToEdit, reset]);

  const mutation = useMutation({
    mutationFn: (data: FormValues) => {
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
      if (noticeToEdit) {
        return noticesApi.updateNotice(noticeToEdit.id, payload);
      }
      return noticesApi.createNotice(payload);
    },
    onSuccess: (_, variables) => {
      addToast({
        type: 'success',
        title: noticeToEdit ? 'Notice Updated' : 'Notice Created',
        message:
          variables.status === 'PUBLISHED'
            ? 'Notice published and queued for push notification dispatch.'
            : 'Notice saved as draft.',
      });
      queryClient.invalidateQueries({ queryKey: ['notices'] });
      reset();
      onOpenChange(false);
      onSuccess();
    },
  });

  const selectedCategory = watch('category');
  const selectedPriority = watch('priority');
  const selectedTargetType = watch('target_type');
  const selectedStatus = watch('status');

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[580px]">
        <DialogHeader>
          <div className="flex items-center gap-2 text-primary">
            <Megaphone className="h-5 w-5" />
            <DialogTitle>{noticeToEdit ? 'Edit Notice' : 'Broadcast Notice'}</DialogTitle>
          </div>
          <DialogDescription>
            {noticeToEdit
              ? 'Modify notice details, target audience, or publication status.'
              : 'Publish an institutional broadcast to students, specific cohorts, or departments.'}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit((d) => mutation.mutate(d))} className="space-y-4 py-2">
          {mutation.error && (
            <div className="flex items-center gap-2 rounded-md bg-destructive/10 p-3 text-xs text-destructive">
              <AlertCircle className="h-4 w-4 shrink-0" />
              <span>
                {mutation.error instanceof Error ? mutation.error.message : 'Failed to save notice'}
              </span>
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
            {errors.title && <p className="text-xs text-destructive">{errors.title.message}</p>}
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Category
              </label>
              <Select
                value={selectedCategory}
                onValueChange={(v) => setValue('category', v as FormValues['category'])}
              >
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="GENERAL">General</SelectItem>
                  <SelectItem value="ACADEMIC">Academic</SelectItem>
                  <SelectItem value="EXAM">Exam</SelectItem>
                  <SelectItem value="HOSTEL">Hostel</SelectItem>
                  <SelectItem value="MESS">Mess</SelectItem>
                  <SelectItem value="SECURITY">Security</SelectItem>
                  <SelectItem value="EVENT">Event</SelectItem>
                  <SelectItem value="FEE">Fee</SelectItem>
                  <SelectItem value="OTHER">Other</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Priority
              </label>
              <Select
                value={selectedPriority}
                onValueChange={(v) => setValue('priority', v as FormValues['priority'])}
              >
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="NORMAL">Normal</SelectItem>
                  <SelectItem value="HIGH">High</SelectItem>
                  <SelectItem value="URGENT">Urgent (Immediate Push)</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Target Audience
              </label>
              <Select
                value={selectedTargetType}
                onValueChange={(v) => setValue('target_type', v as FormValues['target_type'])}
              >
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="ALL">All Students (Campus-wide)</SelectItem>
                  <SelectItem value="BRANCH">Specific Branch</SelectItem>
                  <SelectItem value="YEAR">Specific Academic Year</SelectItem>
                  <SelectItem value="STUDENT">Single Student ID</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Status
              </label>
              <Select
                value={selectedStatus}
                onValueChange={(v) => setValue('status', v as FormValues['status'])}
              >
                <SelectTrigger className="h-9 text-xs">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="PUBLISHED">Publish Immediately</SelectItem>
                  <SelectItem value="DRAFT">Save as Draft</SelectItem>
                </SelectContent>
              </Select>
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
            {errors.body && <p className="text-xs text-destructive">{errors.body.message}</p>}
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
              Expiry Date (Optional)
            </label>
            <Input type="date" {...register('expires_at')} />
          </div>

          <DialogFooter className="pt-2">
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              Cancel
            </Button>
            <Button type="submit" loading={mutation.isPending}>
              {noticeToEdit ? 'Save Changes' : 'Broadcast Notice'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
};

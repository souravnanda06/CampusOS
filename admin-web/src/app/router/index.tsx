import { createBrowserRouter, Navigate } from 'react-router-dom';
import { AppShell } from '@/components/layout/app-shell';
import { ProtectedRoute } from '@/features/auth/ProtectedRoute';
import { LoginPage } from '@/features/auth/LoginPage';

// Operational Feature Pages
import { DashboardPage } from '@/features/dashboard/DashboardPage';
import { StudentsPage } from '@/features/students/StudentsPage';
import { ComplaintsPage } from '@/features/complaints/ComplaintsPage';
import { AttendancePage } from '@/features/attendance/AttendancePage';
import { AcademicPage } from '@/features/academic/AcademicPage';
import { HostelPage } from '@/features/hostel/HostelPage';
import { FeesPage } from '@/features/fees/FeesPage';
import { DocumentsPage } from '@/features/documents/DocumentsPage';
import { VisitorsPage } from '@/features/visitors/VisitorsPage';
import { MessPage } from '@/features/mess/MessPage';
import { NoticesPage } from '@/features/notices/NoticesPage';
import { NotificationsPage } from '@/features/notifications/NotificationsPage';
import { SecurityPage } from '@/features/security/SecurityPage';
import { PassportPage } from '@/features/passport/PassportPage';
import { AuditPage } from '@/features/audit/AuditPage';
import { SearchPage } from '@/features/search/SearchPage';

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    path: '/',
    element: (
      <ProtectedRoute>
        <AppShell />
      </ProtectedRoute>
    ),
    children: [
      {
        index: true,
        element: <DashboardPage />,
      },
      {
        path: 'people',
        element: <StudentsPage />,
      },
      {
        path: 'people/:id',
        element: <StudentsPage />,
      },
      {
        path: 'students',
        element: <Navigate to="/people" replace />,
      },
      {
        path: 'complaints',
        element: <ComplaintsPage />,
      },
      {
        path: 'complaints/:id',
        element: <ComplaintsPage />,
      },
      {
        path: 'attendance',
        element: <AttendancePage />,
      },
      {
        path: 'academic',
        element: <AcademicPage />,
      },
      {
        path: 'hostel',
        element: <HostelPage />,
      },
      {
        path: 'fees',
        element: <FeesPage />,
      },
      {
        path: 'documents',
        element: <DocumentsPage />,
      },
      {
        path: 'visitors',
        element: <VisitorsPage />,
      },
      {
        path: 'mess',
        element: <MessPage />,
      },
      {
        path: 'notices',
        element: <NoticesPage />,
      },
      {
        path: 'notifications',
        element: <NotificationsPage />,
      },
      {
        path: 'security',
        element: <SecurityPage />,
      },
      {
        path: 'passport',
        element: <PassportPage />,
      },
      {
        path: 'audit',
        element: <AuditPage />,
      },
      {
        path: 'search',
        element: <SearchPage />,
      },
      {
        path: '*',
        element: <Navigate to="/" replace />,
      },
    ],
  },
]);

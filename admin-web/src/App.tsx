import { RouterProvider } from 'react-router-dom';
import { router } from './app/router';
import { AppQueryProvider } from './app/providers/QueryProvider';
import { ThemeProvider } from './components/theme-provider';
import { AuthProvider } from './features/auth/AuthContext';
import { ToastProvider } from './components/ui/toast';

export function App() {
  return (
    <ThemeProvider defaultTheme="light" storageKey="campusos-ui-theme">
      <AppQueryProvider>
        <AuthProvider>
          <ToastProvider>
            <RouterProvider router={router} />
          </ToastProvider>
        </AuthProvider>
      </AppQueryProvider>
    </ThemeProvider>
  );
}

export default App;

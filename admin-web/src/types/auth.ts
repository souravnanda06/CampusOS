export type UserRole =
  | 'admin'
  | 'administrator'
  | 'superadmin'
  | 'dean'
  | 'warden'
  | 'teacher'
  | 'faculty'
  | 'security'
  | 'guard'
  | 'security_guard'
  | 'mess_staff'
  | 'mess'
  | 'staff'
  | 'student'

export const ALLOWED_CONSOLE_ROLES: UserRole[] = [
  'admin',
  'administrator',
  'superadmin',
  'dean',
  'warden',
  'staff',
  'teacher',
  'faculty',
  'security',
  'guard',
  'security_guard',
  'mess_staff',
  'mess',
]

export function normalizeRole(role?: string | null): UserRole {
  return (role || 'student').toLowerCase().trim() as UserRole
}

export function isConsoleAuthorizedRole(role?: string | null): boolean {
  return ALLOWED_CONSOLE_ROLES.includes(normalizeRole(role))
}

export function isFullAdminRole(role?: string | null): boolean {
  const r = normalizeRole(role)
  return r === 'admin' || r === 'administrator' || r === 'superadmin' || r === 'dean' || r === 'staff'
}

export interface User {
  id: string
  name: string
  email: string
  role: UserRole
  registrationNumber?: string
  course?: string
  branch?: string
  year?: string | number
  deviceId?: string
  approvalStatus?: string
  photoUrl?: string | null
}

export interface LoginResponse {
  message: string
  token: string
  user: User
}

export interface AuthState {
  user: User | null
  token: string | null
  isAuthenticated: boolean
  isLoading: boolean
}

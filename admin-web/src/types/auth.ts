export type UserRole =
  | 'admin'
  | 'warden'
  | 'teacher'
  | 'faculty'
  | 'security'
  | 'mess_staff'
  | 'staff'
  | 'student'

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

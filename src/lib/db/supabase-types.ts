export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      admin_requests: {
        Row: {
          id: string
          user_id: string
          reason: string
          status: 'pending' | 'approved' | 'rejected'
          requested_at: string
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          reason: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          reason?: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          updated_at?: string | null
        }
      }
      groups: {
        Row: {
          id: string
          name: string
          type: 'standard' | 'lottery'
          created_by: string
          monthly_contribution_amount: number
          created_at: string
          updated_at: string | null
        }
        Insert: {
          id?: string
          name: string
          type: 'standard' | 'lottery'
          created_by: string
          monthly_contribution_amount: number
          created_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          name?: string
          type?: 'standard' | 'lottery'
          created_by?: string
          monthly_contribution_amount?: number
          created_at?: string
          updated_at?: string | null
        }
      }
      group_join_requests: {
        Row: {
          id: string
          user_id: string
          group_id: string
          status: 'pending' | 'approved' | 'rejected'
          requested_at: string
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          group_id: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          group_id?: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          updated_at?: string | null
        }
      }
      users: {
        Row: {
          id: string
          email: string
          is_admin: boolean
          is_site_master: boolean
          group_id: string | null
          created_at: string
          updated_at: string | null
        }
        Insert: {
          id: string
          email: string
          is_admin?: boolean
          is_site_master?: boolean
          group_id?: string | null
          created_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          email?: string
          is_admin?: boolean
          is_site_master?: boolean
          group_id?: string | null
          created_at?: string
          updated_at?: string | null
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      check_admin_request_eligibility: {
        Args: { user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
  }
} 
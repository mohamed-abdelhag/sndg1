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
          responded_at: string | null
          responded_by: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          reason: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          responded_at?: string | null
          responded_by?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          reason?: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          responded_at?: string | null
          responded_by?: string | null
          updated_at?: string | null
        }
      }
      groups: {
        Row: {
          id: string
          name: string
          description: string
          type: 'standard' | 'lottery'
          created_by: string
          monthly_contribution_amount: number
          total_pool: number
          start_month_year: string
          created_at: string
          updated_at: string | null
        }
        Insert: {
          id?: string
          name: string
          description: string
          type: 'standard' | 'lottery'
          created_by: string
          monthly_contribution_amount: number
          total_pool?: number
          start_month_year: string
          created_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          name?: string
          description?: string
          type?: 'standard' | 'lottery'
          created_by?: string
          monthly_contribution_amount?: number
          total_pool?: number
          start_month_year?: string
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
          responded_at: string | null
          responded_by: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          user_id: string
          group_id: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          responded_at?: string | null
          responded_by?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          user_id?: string
          group_id?: string
          status?: 'pending' | 'approved' | 'rejected'
          requested_at?: string
          responded_at?: string | null
          responded_by?: string | null
          updated_at?: string | null
        }
      }
      users: {
        Row: {
          id: string
          email: string
          first_name: string | null
          last_name: string | null
          is_admin: boolean
          is_site_master: boolean
          group_id: string | null
          created_at: string
          updated_at: string | null
        }
        Insert: {
          id: string
          email: string
          first_name?: string | null
          last_name?: string | null
          is_admin?: boolean
          is_site_master?: boolean
          group_id?: string | null
          created_at?: string
          updated_at?: string | null
        }
        Update: {
          id?: string
          email?: string
          first_name?: string | null
          last_name?: string | null
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
      create_group_tables: {
        Args: { group_id: string }
        Returns: void
      }
      add_member_to_matrix: {
        Args: { group_id: string, user_id: string }
        Returns: void
      }
      add_next_month_to_matrix: {
        Args: Record<string, never>
        Returns: void
      }
      approve_admin_request: {
        Args: { request_id: string, approved_by: string }
        Returns: boolean
      }
      approve_join_request: {
        Args: { request_id: string, approved_by: string }
        Returns: boolean
      }
      select_lottery_winner: {
        Args: { group_id: string }
        Returns: string
      }
      record_contribution: {
        Args: { user_id: string, amount: number, withdrawal_amount?: number, payback_amount?: number }
        Returns: boolean
      }
      initialize_first_site_master: {
        Args: { email: string }
        Returns: boolean
      }
      trigger_set_timestamp: {
        Args: Record<string, never>
        Returns: void
      }
    }
    Enums: {
      [_ in never]: never
    }
  }
} 
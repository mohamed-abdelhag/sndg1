create or replace function check_admin_request_eligibility(user_id uuid)
returns boolean as $$
declare
    in_group boolean;
    existing_request boolean;
begin
    select exists (
        select 1 from users 
        where id = user_id and group_id is not null
    ) into in_group;

    select exists (
        select 1 from admin_requests 
        where user_id = user_id and status = 'pending'
    ) into existing_request;

    return not in_group and not existing_request;
end;
$$ language plpgsql;

create or replace function approve_admin_request(request_id uuid, site_master_id uuid)
returns void as $$
begin
  -- Update admin request status
  update admin_requests
  set status = 'approved',
      updated_at = now()
  where id = request_id;

  -- Grant admin privileges
  update users
  set is_admin = true,
      updated_at = now()
  where id = (select user_id from admin_requests where id = request_id);
end;
$$ language plpgsql;

create or replace function reject_admin_request(request_id uuid, site_master_id uuid)
returns void as $$
begin
  update admin_requests
  set status = 'rejected',
      updated_at = now()
  where id = request_id;
end;
$$ language plpgsql; 
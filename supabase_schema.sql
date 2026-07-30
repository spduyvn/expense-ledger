-- Chạy trong Supabase SQL Editor

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  amount numeric not null,          -- số âm = chi, số dương = thu
  note text,
  account_type text not null default 'cash'
    check (account_type in ('cash', 'bank', 'wallet')),
  tag text,
  created_at timestamptz not null default now()
);

-- Migration cho bảng entries đã tồn tại: giao dịch cũ được xem là tiền mặt.
alter table entries add column if not exists account_type text;
update entries set account_type = 'cash' where account_type is null;
alter table entries alter column account_type set default 'cash';
alter table entries alter column account_type set not null;
alter table entries add column if not exists tag text;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'entries_account_type_check'
  ) then
    alter table entries
      add constraint entries_account_type_check
      check (account_type in ('cash', 'bank', 'wallet'));
  end if;
end $$;

-- Bật Row Level Security
alter table entries enable row level security;

-- Cho phép đọc/ghi công khai bằng anon key (phù hợp app cá nhân, 1 người dùng).
-- Nếu muốn nhiều người dùng riêng biệt, thêm cột user_id và đổi policy theo auth.uid().
create policy "allow all for anon" on entries
  for all
  using (true)
  with check (true);

-- Chạy trong Supabase SQL Editor

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  amount numeric not null,          -- số âm = chi, số dương = thu
  note text,
  account_type text not null default 'cash'
    check (account_type in ('cash', 'bank', 'wallet')),
  tag text,
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

-- Migration cho bảng entries đã tồn tại: giao dịch cũ được xem là tiền mặt.
alter table entries add column if not exists account_type text;
update entries set account_type = 'cash' where account_type is null;
alter table entries alter column account_type set default 'cash';
alter table entries alter column account_type set not null;
alter table entries add column if not exists tag text;

-- Migration an toàn cho bảng cũ: các dòng cũ không thể tự xác định chủ sở hữu,
-- nên vẫn giữ nguyên dữ liệu và bị ẩn cho đến khi bạn gán user_id đúng cho chúng.
alter table entries add column if not exists user_id uuid references auth.users(id);
alter table entries alter column user_id set default auth.uid();

do $$
begin
  if not exists (select 1 from entries where user_id is null) then
    alter table entries alter column user_id set not null;
  else
    raise notice 'Các giao dịch cũ chưa có user_id được giữ nguyên và sẽ bị ẩn. Gán user_id cho chúng trước khi đặt cột thành NOT NULL.';
  end if;
end $$;

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

-- Thay các policy công khai cũ bằng policy theo người dùng. Có thể chạy lại an toàn.
drop policy if exists "allow all for anon" on entries;
drop policy if exists "Users can select their own entries" on entries;
drop policy if exists "Users can insert their own entries" on entries;
drop policy if exists "Users can update their own entries" on entries;
drop policy if exists "Users can delete their own entries" on entries;

create policy "Users can select their own entries" on entries
  for select using (user_id = auth.uid());

create policy "Users can insert their own entries" on entries
  for insert with check (user_id = auth.uid());

create policy "Users can update their own entries" on entries
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Users can delete their own entries" on entries
  for delete using (user_id = auth.uid());

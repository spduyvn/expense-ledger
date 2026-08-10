-- Chạy trong Supabase SQL Editor

create table if not exists entries (
  id uuid primary key default gen_random_uuid(),
  amount numeric not null,          -- số âm = chi, số dương = thu
  note text,
  account_type text not null default 'cash'
    check (account_type in ('cash', 'bank', 'wallet')),
  tag text,
  entry_type text not null default 'transaction'
    check (entry_type in ('transaction', 'adjustment')),
  counts_toward_daily boolean not null default true,
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

-- Migration cho bảng entries đã tồn tại: giao dịch cũ được xem là tiền mặt.
alter table entries add column if not exists account_type text;
update entries set account_type = 'cash' where account_type is null;
alter table entries alter column account_type set default 'cash';
alter table entries alter column account_type set not null;
alter table entries add column if not exists tag text;
alter table entries add column if not exists entry_type text;
update entries set entry_type = 'transaction' where entry_type is null;
alter table entries alter column entry_type set default 'transaction';
alter table entries alter column entry_type set not null;
alter table entries add column if not exists counts_toward_daily boolean;
update entries set counts_toward_daily = true where counts_toward_daily is null;
alter table entries alter column counts_toward_daily set default true;
alter table entries alter column counts_toward_daily set not null;

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

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'entries_entry_type_check'
  ) then
    alter table entries
      add constraint entries_entry_type_check
      check (entry_type in ('transaction', 'adjustment'));
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

create table if not exists tags (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

alter table tags enable row level security;

drop policy if exists "Users can select their own tags" on tags;
drop policy if exists "Users can insert their own tags" on tags;
drop policy if exists "Users can update their own tags" on tags;
drop policy if exists "Users can delete their own tags" on tags;

create policy "Users can select their own tags" on tags
  for select using (user_id = auth.uid());
create policy "Users can insert their own tags" on tags
  for insert with check (user_id = auth.uid());
create policy "Users can update their own tags" on tags
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can delete their own tags" on tags
  for delete using (user_id = auth.uid());

create table if not exists debts (
  id uuid primary key default gen_random_uuid(),
  amount numeric not null,             -- dương = phát sinh nợ, âm = trả nợ
  note text,
  debt_type text not null default 'owed'
    check (debt_type in ('owed', 'lent')),
  created_at timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id)
);

-- Migration: các dòng nợ cũ được xem là khoản bạn đang nợ.
alter table debts add column if not exists debt_type text;
update debts set debt_type = 'owed' where debt_type is null;
alter table debts alter column debt_type set default 'owed';
alter table debts alter column debt_type set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'debts_debt_type_check'
  ) then
    alter table debts
      add constraint debts_debt_type_check
      check (debt_type in ('owed', 'lent'));
  end if;
end $$;

alter table debts enable row level security;

drop policy if exists "Users can select their own debts" on debts;
drop policy if exists "Users can insert their own debts" on debts;
drop policy if exists "Users can update their own debts" on debts;
drop policy if exists "Users can delete their own debts" on debts;

create policy "Users can select their own debts" on debts
  for select using (user_id = auth.uid());
create policy "Users can insert their own debts" on debts
  for insert with check (user_id = auth.uid());
create policy "Users can update their own debts" on debts
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can delete their own debts" on debts
  for delete using (user_id = auth.uid());

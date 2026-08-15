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

-- Sổ nợ theo khoản: một khoản nợ có thể phát sinh và được trả dần qua nhiều tháng.
create table if not exists debt_accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  note text,
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  closed_at timestamptz
);

create table if not exists debt_entries (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references debt_accounts(id) on delete cascade,
  amount numeric not null check (amount <> 0),
  entry_type text not null check (entry_type in ('opening', 'increase', 'payment', 'adjustment')),
  note text,
  occurred_at timestamptz not null default now(),
  ledger_entry_id uuid references entries(id),
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists debt_month_plans (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references debt_accounts(id) on delete cascade,
  month date not null check (month = date_trunc('month', month)::date),
  planned_amount numeric not null check (planned_amount > 0),
  user_id uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now(),
  unique (debt_id, month)
);

alter table debt_accounts enable row level security;
alter table debt_entries enable row level security;
alter table debt_month_plans enable row level security;

drop policy if exists "Users can manage their own debt accounts" on debt_accounts;
drop policy if exists "Users can manage their own debt entries" on debt_entries;
drop policy if exists "Users can manage their own debt plans" on debt_month_plans;

create policy "Users can manage their own debt accounts" on debt_accounts
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can manage their own debt entries" on debt_entries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can manage their own debt plans" on debt_month_plans
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create index if not exists debt_entries_user_debt_occurred_at_idx
  on debt_entries (user_id, debt_id, occurred_at desc);
create index if not exists debt_month_plans_user_debt_month_idx
  on debt_month_plans (user_id, debt_id, month);

create or replace function create_debt_account(
  p_name text,
  p_note text,
  p_opening_amount numeric,
  p_plans jsonb default '[]'::jsonb
) returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_debt_id uuid;
  v_plan jsonb;
begin
  if auth.uid() is null or coalesce(trim(p_name), '') = '' or p_opening_amount <= 0 then
    raise exception 'Thông tin khoản nợ không hợp lệ';
  end if;

  insert into debt_accounts (name, note) values (trim(p_name), p_note) returning id into v_debt_id;
  insert into debt_entries (debt_id, amount, entry_type, note)
  values (v_debt_id, p_opening_amount, 'opening', coalesce(p_note, 'Dư nợ ban đầu'));

  for v_plan in select value from jsonb_array_elements(coalesce(p_plans, '[]'::jsonb)) loop
    insert into debt_month_plans (debt_id, month, planned_amount)
    values (v_debt_id, (v_plan->>'month')::date, (v_plan->>'amount')::numeric)
    on conflict (debt_id, month) do update
      set planned_amount = debt_month_plans.planned_amount + excluded.planned_amount;
  end loop;
  return v_debt_id;
end;
$$;

create or replace function add_debt_increase(
  p_debt_id uuid,
  p_amount numeric,
  p_note text,
  p_plans jsonb default '[]'::jsonb
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_plan jsonb;
begin
  if p_amount <= 0 or not exists (select 1 from debt_accounts where id = p_debt_id and user_id = auth.uid()) then
    raise exception 'Khoản nợ hoặc số tiền không hợp lệ';
  end if;
  insert into debt_entries (debt_id, amount, entry_type, note)
  values (p_debt_id, p_amount, 'increase', p_note);
  for v_plan in select value from jsonb_array_elements(coalesce(p_plans, '[]'::jsonb)) loop
    insert into debt_month_plans (debt_id, month, planned_amount)
    values (p_debt_id, (v_plan->>'month')::date, (v_plan->>'amount')::numeric)
    on conflict (debt_id, month) do update
      set planned_amount = debt_month_plans.planned_amount + excluded.planned_amount;
  end loop;
end;
$$;

create or replace function pay_debt(
  p_debt_id uuid,
  p_amount numeric,
  p_account_type text,
  p_note text default null
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_balance numeric;
  v_ledger_entry_id uuid;
  v_name text;
begin
  select coalesce(sum(amount), 0), max(debt_accounts.name)
  into v_balance, v_name
  from debt_entries
  join debt_accounts on debt_accounts.id = debt_entries.debt_id
  where debt_entries.debt_id = p_debt_id and debt_entries.user_id = auth.uid()
  group by debt_entries.debt_id;

  if p_amount <= 0 or v_balance is null or p_amount > v_balance then
    raise exception 'Số tiền trả không hợp lệ';
  end if;
  if p_account_type not in ('cash', 'bank', 'wallet') then
    raise exception 'Nguồn tiền không hợp lệ';
  end if;

  insert into entries (amount, note, account_type, entry_type, counts_toward_daily)
  values (-p_amount, coalesce(p_note, 'Trả nợ: ' || v_name), p_account_type, 'transaction', false)
  returning id into v_ledger_entry_id;

  insert into debt_entries (debt_id, amount, entry_type, note, ledger_entry_id)
  values (p_debt_id, -p_amount, 'payment', coalesce(p_note, 'Thanh toán: ' || v_name), v_ledger_entry_id);
end;
$$;

create or replace function update_debt_account(
  p_debt_id uuid,
  p_name text,
  p_note text
) returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Tên khoản nợ không hợp lệ';
  end if;
  update debt_accounts set name = trim(p_name), note = p_note
  where id = p_debt_id and user_id = auth.uid();
  if not found then raise exception 'Không tìm thấy khoản nợ'; end if;
end;
$$;

create or replace function delete_debt_account(p_debt_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if exists (select 1 from debt_entries where debt_id = p_debt_id and ledger_entry_id is not null and user_id = auth.uid()) then
    raise exception 'Không thể xoá khoản nợ đã có thanh toán';
  end if;
  delete from debt_accounts where id = p_debt_id and user_id = auth.uid();
  if not found then raise exception 'Không tìm thấy khoản nợ'; end if;
end;
$$;

create or replace function save_debt_plan(
  p_debt_id uuid,
  p_month date,
  p_amount numeric
) returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_amount <= 0 or p_month <> date_trunc('month', p_month)::date
    or not exists (select 1 from debt_accounts where id = p_debt_id and user_id = auth.uid()) then
    raise exception 'Lịch trả không hợp lệ';
  end if;
  insert into debt_month_plans (debt_id, month, planned_amount)
  values (p_debt_id, p_month, p_amount)
  on conflict (debt_id, month) do update set planned_amount = excluded.planned_amount;
end;
$$;

create or replace function delete_debt_plan(p_debt_id uuid, p_month date)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  delete from debt_month_plans
  where debt_id = p_debt_id and month = p_month and user_id = auth.uid();
  if not found then raise exception 'Không tìm thấy lịch trả'; end if;
end;
$$;

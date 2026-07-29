-- Chạy trong Supabase SQL Editor

create table entries (
  id uuid primary key default gen_random_uuid(),
  amount numeric not null,          -- số âm = chi, số dương = thu
  note text,
  created_at timestamptz not null default now()
);

-- Bật Row Level Security
alter table entries enable row level security;

-- Cho phép đọc/ghi công khai bằng anon key (phù hợp app cá nhân, 1 người dùng).
-- Nếu muốn nhiều người dùng riêng biệt, thêm cột user_id và đổi policy theo auth.uid().
create policy "allow all for anon" on entries
  for all
  using (true)
  with check (true);

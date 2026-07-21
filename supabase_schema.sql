-- =====================================================================
-- ชีวะกับพี่อาร์ — Tutor Management System
-- Supabase schema: tables + Row Level Security + Realtime
-- วิธีใช้: เปิด Supabase Dashboard -> SQL Editor -> New query
--         วางไฟล์นี้ทั้งหมด แล้วกด RUN ครั้งเดียว (รันซ้ำได้ ไม่พัง)
-- =====================================================================

-- ต้องเปิด extension นี้ไว้เพื่อใช้ gen_random_uuid()
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- ฟังก์ชันช่วย: อัปเดตคอลัมน์ updated_at อัตโนมัติทุกครั้งที่มีการ UPDATE
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- ---------------------------------------------------------------------
-- 1) settings — ตั้งค่าของติวเตอร์ 1 แถวต่อ 1 ผู้ใช้ (วันหยุด / พร้อมเพย์ / ข้อมูลออกเอกสาร)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  user_id            uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  is_holiday         boolean not null default false,
  holiday_reason     text not null default '',
  holiday_start      text not null default '',   -- เก็บรูปแบบ "YYYY-MM-DD|HH:MM"
  holiday_return     text not null default '',
  promptpay_id       text not null default '',
  drive_folder_url   text not null default '',
  business_name      text not null default 'สถาบันกวดวิชา',
  business_address   text not null default '',
  business_phone     text not null default '',
  business_tax_id    text not null default '',
  bank_name          text not null default '',
  bank_account_no    text not null default '',
  bank_account_name  text not null default '',
  signature_name     text not null default '',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2) courses — หลักสูตร/คอร์สสำเร็จรูป
-- ---------------------------------------------------------------------
create table if not exists public.courses (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  title        text not null,
  description  text not null default '',
  type         text not null default '',
  hours        numeric not null default 0,
  price        numeric not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3) students — นักเรียน / คลาสเรียน
-- ---------------------------------------------------------------------
create table if not exists public.students (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name             text not null,
  type             text not null default 'เดี่ยว',       -- เดี่ยว | กลุ่ม
  course_type      text not null default 'คอร์ส',        -- คอร์ส | รายชั่วโมง | รายปี
  teaching_type    text not null default 'ออนไลน์',      -- ออนไลน์ | ออนไซต์
  hours_total      numeric not null default 0,
  hours_used       numeric not null default 0,
  price            numeric not null default 0,
  base_price       numeric not null default 0,
  discount         numeric not null default 0,
  payment_status   text not null default 'ยังไม่ชำระ',   -- ชำระแล้ว | ยังไม่ชำระ | ค้างชำระ
  payment_method   text not null default '',
  payment_date     text not null default '',
  payment_time     text not null default '',
  payer_name       text not null default '',
  status           text not null default 'กำลังเรียน',   -- กำลังเรียน | จบคอร์ส
  members          jsonb not null default '[]'::jsonb,
  schedules        jsonb not null default '[]'::jsonb,
  leaves           jsonb not null default '[]'::jsonb,
  renewals         jsonb not null default '[]'::jsonb,
  meet_link        text not null default '',
  start_date       text not null default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 4) teaching_logs — บันทึกการสอน
-- ---------------------------------------------------------------------
create table if not exists public.teaching_logs (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  date         date not null default current_date,
  topic        text not null default '',
  hours        numeric not null default 0,
  notes        text not null default '',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5) exam_scores — คะแนนสอบ
-- ---------------------------------------------------------------------
create table if not exists public.exam_scores (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  student_id   uuid not null references public.students(id) on delete cascade,
  exam_type    text not null default '',
  topic        text not null default '',
  attempt      integer not null default 1,
  score        numeric not null default 0,
  max_score    numeric not null default 0,
  date         date not null default current_date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 6) finances — รายรับ/รายจ่าย
-- ---------------------------------------------------------------------
create table if not exists public.finances (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  date         date not null default current_date,
  description  text not null default '',
  amount       numeric not null default 0,
  type         text not null default 'income',  -- income | expense
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7) materials — ชีทเรียน / เอกสาร
-- ---------------------------------------------------------------------
create table if not exists public.materials (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  title        text not null,
  topic        text not null default '',
  link         text not null default '',
  date         date not null default current_date,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 8) tasks — สิ่งที่ต้องทำ
-- ---------------------------------------------------------------------
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  text         text not null,
  completed    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 9) quick_replies — ข้อความตอบกลับด่วน
-- ---------------------------------------------------------------------
create table if not exists public.quick_replies (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade default auth.uid(),
  title        text not null,
  text         text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------
create index if not exists idx_students_user       on public.students(user_id);
create index if not exists idx_logs_user            on public.teaching_logs(user_id);
create index if not exists idx_logs_student         on public.teaching_logs(student_id);
create index if not exists idx_scores_user          on public.exam_scores(user_id);
create index if not exists idx_scores_student       on public.exam_scores(student_id);
create index if not exists idx_finances_user        on public.finances(user_id);
create index if not exists idx_materials_user       on public.materials(user_id);
create index if not exists idx_courses_user         on public.courses(user_id);
create index if not exists idx_tasks_user           on public.tasks(user_id);
create index if not exists idx_quick_replies_user   on public.quick_replies(user_id);

-- ---------------------------------------------------------------------
-- Triggers: updated_at
-- ---------------------------------------------------------------------
drop trigger if exists trg_settings_updated on public.settings;
create trigger trg_settings_updated before update on public.settings for each row execute function public.set_updated_at();

drop trigger if exists trg_courses_updated on public.courses;
create trigger trg_courses_updated before update on public.courses for each row execute function public.set_updated_at();

drop trigger if exists trg_students_updated on public.students;
create trigger trg_students_updated before update on public.students for each row execute function public.set_updated_at();

drop trigger if exists trg_logs_updated on public.teaching_logs;
create trigger trg_logs_updated before update on public.teaching_logs for each row execute function public.set_updated_at();

drop trigger if exists trg_scores_updated on public.exam_scores;
create trigger trg_scores_updated before update on public.exam_scores for each row execute function public.set_updated_at();

drop trigger if exists trg_finances_updated on public.finances;
create trigger trg_finances_updated before update on public.finances for each row execute function public.set_updated_at();

drop trigger if exists trg_materials_updated on public.materials;
create trigger trg_materials_updated before update on public.materials for each row execute function public.set_updated_at();

drop trigger if exists trg_tasks_updated on public.tasks;
create trigger trg_tasks_updated before update on public.tasks for each row execute function public.set_updated_at();

drop trigger if exists trg_quick_replies_updated on public.quick_replies;
create trigger trg_quick_replies_updated before update on public.quick_replies for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Row Level Security: เปิดใช้งานทุกตาราง แล้วอนุญาตเฉพาะเจ้าของข้อมูล (auth.uid() = user_id)
-- ---------------------------------------------------------------------
alter table public.settings       enable row level security;
alter table public.courses        enable row level security;
alter table public.students       enable row level security;
alter table public.teaching_logs  enable row level security;
alter table public.exam_scores    enable row level security;
alter table public.finances       enable row level security;
alter table public.materials      enable row level security;
alter table public.tasks          enable row level security;
alter table public.quick_replies  enable row level security;

-- ลบ policy เดิม (ถ้ามี) ก่อนสร้างใหม่ เพื่อให้รันซ้ำได้โดยไม่ error
drop policy if exists "owner_all" on public.settings;
drop policy if exists "owner_all" on public.courses;
drop policy if exists "owner_all" on public.students;
drop policy if exists "owner_all" on public.teaching_logs;
drop policy if exists "owner_all" on public.exam_scores;
drop policy if exists "owner_all" on public.finances;
drop policy if exists "owner_all" on public.materials;
drop policy if exists "owner_all" on public.tasks;
drop policy if exists "owner_all" on public.quick_replies;

create policy "owner_all" on public.settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.courses
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.students
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.teaching_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.exam_scores
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.finances
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.materials
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owner_all" on public.quick_replies
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ---------------------------------------------------------------------
-- Realtime: เพิ่มทุกตารางเข้า publication เพื่อให้ realtime sync ทำงาน
-- (ถ้าตารางถูกเพิ่มไปแล้ว คำสั่งนี้จะ error แบบ "already member" ซึ่งไม่เป็นไร
--  ให้รันทีละบรรทัดถ้าเจอ error นี้ หรือข้ามบรรทัดที่ error ไปได้เลย)
-- ---------------------------------------------------------------------
do $$
begin
  begin
    alter publication supabase_realtime add table public.students;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.teaching_logs;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.exam_scores;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.finances;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.materials;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.courses;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.tasks;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.quick_replies;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.settings;
  exception when duplicate_object then null;
  end;
end $$;

-- =====================================================================
-- เสร็จแล้ว! ขั้นตอนถัดไป:
-- 1. ไปที่ Authentication -> Users -> Add user เพื่อสร้างบัญชีล็อกอินของพี่อาร์เอง
--    (แนะนำ: Authentication -> Providers -> ปิด "Allow new users to sign up"
--     เพื่อไม่ให้คนอื่นสมัครเข้าระบบเองได้ เพราะแอปนี้มีผู้ใช้แค่คนเดียว)
-- 2. ไปที่ Project Settings -> API เพื่อคัดลอก Project URL และ anon public key
--    แล้วนำไปวางในไฟล์ index.html ที่ส่วน SUPABASE CONFIG ด้านบนของไฟล์
-- =====================================================================

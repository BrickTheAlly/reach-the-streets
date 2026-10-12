-- Agent-ops schema — Brick's own operational record-keeping.
-- Wired into reachthestreets-operations alongside the business tables (0001).
-- Purpose: track my own tasks, decisions, knowledge, milestones, origin files, and daily activity.

-- 1) agent_tasks — Brick's internal task queue (distinct from client-facing tasks)
create table if not exists public.agent_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  status text not null default 'todo' check (status in ('todo','in_progress','done','blocked')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  source text,
  client_task_id uuid references public.tasks(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

-- 2) agent_decisions — decisions, grants, denials (PERMISSIONS.md mirror)
create table if not exists public.agent_decisions (
  id uuid primary key default gen_random_uuid(),
  subject text not null,
  decision text not null check (decision in ('granted','denied','one_time','note')),
  scope text,
  notes text,
  decided_at timestamptz not null default now(),
  expires_at timestamptz
);

-- 3) agent_notes — durable knowledge / working notes
create table if not exists public.agent_notes (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text,
  tags text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) agent_milestones — playbook / phase progress tracking
create table if not exists public.agent_milestones (
  id uuid primary key default gen_random_uuid(),
  playbook text not null,
  phase text,
  milestone_key text,
  label text not null,
  status text not null default 'pending' check (status in ('pending','in_progress','done','blocked')),
  notes text,
  updated_at timestamptz not null default now()
);

-- 5) origin_files — identity / origin files wired into the DB
create table if not exists public.origin_files (
  id uuid primary key default gen_random_uuid(),
  filename text not null unique,
  content text,
  content_hash text,
  updated_at timestamptz not null default now()
);

-- 6) daily_log — DB-backed daily activity record (mirror of memory/*.md)
create table if not exists public.daily_log (
  id uuid primary key default gen_random_uuid(),
  log_date date not null,
  summary text,
  detail text,
  created_at timestamptz not null default now(),
  unique (log_date)
);

-- indexes
create index if not exists agent_tasks_status_idx on public.agent_tasks(status);
create index if not exists agent_milestones_playbook_idx on public.agent_milestones(playbook, phase);
create index if not exists agent_notes_updated_idx on public.agent_notes(updated_at desc);

-- updated_at trigger for agent_notes
drop trigger if exists agent_notes_updated_at on public.agent_notes;
create trigger agent_notes_updated_at before update on public.agent_notes for each row execute function public.set_updated_at();

-- Row Level Security
alter table public.agent_tasks enable row level security;
alter table public.agent_decisions enable row level security;
alter table public.agent_notes enable row level security;
alter table public.agent_milestones enable row level security;
alter table public.origin_files enable row level security;
alter table public.daily_log enable row level security;

do $$
declare t text;
begin
  foreach t in array array['agent_tasks','agent_decisions','agent_notes','agent_milestones','origin_files','daily_log'] loop
    execute format('drop policy if exists "admin_all" on public.%I', t);
    execute format('create policy "admin_all" on public.%I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'')', t);
  end loop;
end $$;

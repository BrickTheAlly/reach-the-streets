-- Reach the Streets — Operations Database (agent-ops) schema
-- Phase 1.3. Private ops DB; Brick (service role) is the only writer.
create extension if not exists pgcrypto;

-- 1) clients — inmate client records
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  doc_number text,
  facility_name text,
  facility_location text,
  facility_type text,
  securus_contact_id text,
  securus_contact_status text not null default 'pending' check (securus_contact_status in ('pending','approved','blocked')),
  subscription_status text not null default 'trial' check (subscription_status in ('trial','active','paused','cancelled')),
  stripe_customer_id text,
  family_account_id uuid,
  intake_source text check (intake_source in ('brochure','website','referral')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2) tasks — task tracking
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  task_type text not null check (task_type in ('research','paperwork','correspondence','information','planning','education')),
  title text,
  description text,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'pending' check (status in ('pending','in_progress','completed','blocked','cancelled')),
  character_count int not null default 0,
  stamps_used int not null default 0,
  deliverable_ids uuid[],
  rsi_notes text,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz
);

-- 3) billing — subscription/payment records
create table if not exists public.billing (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  subscription_status text not null default 'trial',
  stripe_customer_id text,
  monthly_rate numeric(10,2) not null default 25.00,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4) activity_log — all Brick actions
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  detail jsonb,
  created_at timestamptz not null default now()
);

-- 5) deliverables — completed deliverable metadata
create table if not exists public.deliverables (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id) on delete cascade,
  task_id uuid references public.tasks(id) on delete set null,
  character_count int not null default 0,
  stamps_used int not null default 0,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

-- 6) blockers — current/resolved blockers
create table if not exists public.blockers (
  id uuid primary key default gen_random_uuid(),
  description text not null,
  attempts int not null default 0,
  root_cause text,
  resolution text,
  status text not null default 'open' check (status in ('open','resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

-- indexes
create index if not exists tasks_client_idx on public.tasks(client_id);
create index if not exists tasks_status_idx on public.tasks(status);
create index if not exists tasks_priority_idx on public.tasks(priority);
create index if not exists billing_client_idx on public.billing(client_id);
create index if not exists deliverables_client_idx on public.deliverables(client_id);
create index if not exists activity_log_created_idx on public.activity_log(created_at desc);

-- updated_at trigger
create or replace function public.set_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists clients_updated_at on public.clients;
create trigger clients_updated_at before update on public.clients for each row execute function public.set_updated_at();
drop trigger if exists billing_updated_at on public.billing;
create trigger billing_updated_at before update on public.billing for each row execute function public.set_updated_at();

-- Row Level Security
alter table public.clients enable row level security;
alter table public.tasks enable row level security;
alter table public.billing enable row level security;
alter table public.activity_log enable row level security;
alter table public.deliverables enable row level security;
alter table public.blockers enable row level security;

do $$
declare t text;
begin
  foreach t in array array['clients','tasks','billing','activity_log','deliverables','blockers'] loop
    execute format('drop policy if exists "admin_all" on public.%I', t);
    execute format('create policy "admin_all" on public.%I for all using (auth.role() = ''authenticated'') with check (auth.role() = ''authenticated'')', t);
  end loop;
end $$;

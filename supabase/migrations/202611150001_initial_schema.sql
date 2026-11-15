-- JT-FIT initial schema
-- All private tables are protected by RLS. Public student links are resolved only by Edge Functions.

create extension if not exists pgcrypto;

create table public.students (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  email text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.exercise_library (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete cascade,
  name text not null,
  muscle_group text,
  video_url text,
  created_at timestamptz not null default now()
);

create unique index exercise_library_owner_name_idx
  on public.exercise_library (coalesce(owner_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

create table public.workout_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text not null default 'Geral',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.template_days (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.workout_templates(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  label text not null,
  unique (template_id, day_of_week)
);

create table public.template_exercises (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.template_days(id) on delete cascade,
  exercise_id uuid references public.exercise_library(id) on delete set null,
  exercise_name text not null,
  sets text not null default '3',
  reps text not null default '12',
  rest_seconds integer,
  instructions text,
  position integer not null default 0
);

create table public.shared_workouts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  template_id uuid references public.workout_templates(id) on delete set null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.shared_workout_days (
  id uuid primary key default gen_random_uuid(),
  shared_workout_id uuid not null references public.shared_workouts(id) on delete cascade,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  label text not null,
  position integer not null default 0
);

create table public.shared_workout_exercises (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.shared_workout_days(id) on delete cascade,
  exercise_name text not null,
  video_url text,
  sets text not null,
  reps text not null,
  rest_seconds integer,
  instructions text,
  position integer not null default 0
);

create index shared_workouts_owner_idx on public.shared_workouts(owner_id);
create index shared_workouts_student_idx on public.shared_workouts(student_id);
create index shared_workouts_expiry_idx on public.shared_workouts(expires_at);

alter table public.students enable row level security;
alter table public.exercise_library enable row level security;
alter table public.workout_templates enable row level security;
alter table public.template_days enable row level security;
alter table public.template_exercises enable row level security;
alter table public.shared_workouts enable row level security;
alter table public.shared_workout_days enable row level security;
alter table public.shared_workout_exercises enable row level security;

create policy "Owner manages students" on public.students
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "Owner manages exercise library" on public.exercise_library
  for all to authenticated using (owner_id is null or owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "Owner manages templates" on public.workout_templates
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "Owner manages template days" on public.template_days
  for all to authenticated using (
    exists (select 1 from public.workout_templates t where t.id = template_id and t.owner_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.workout_templates t where t.id = template_id and t.owner_id = (select auth.uid()))
  );

create policy "Owner manages template exercises" on public.template_exercises
  for all to authenticated using (
    exists (
      select 1 from public.template_days d
      join public.workout_templates t on t.id = d.template_id
      where d.id = day_id and t.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.template_days d
      join public.workout_templates t on t.id = d.template_id
      where d.id = day_id and t.owner_id = (select auth.uid())
    )
  );

create policy "Owner manages shared workouts" on public.shared_workouts
  for all to authenticated using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

create policy "Owner manages shared workout days" on public.shared_workout_days
  for all to authenticated using (
    exists (select 1 from public.shared_workouts s where s.id = shared_workout_id and s.owner_id = (select auth.uid()))
  )
  with check (
    exists (select 1 from public.shared_workouts s where s.id = shared_workout_id and s.owner_id = (select auth.uid()))
  );

create policy "Owner manages shared workout exercises" on public.shared_workout_exercises
  for all to authenticated using (
    exists (
      select 1 from public.shared_workout_days d
      join public.shared_workouts s on s.id = d.shared_workout_id
      where d.id = day_id and s.owner_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.shared_workout_days d
      join public.shared_workouts s on s.id = d.shared_workout_id
      where d.id = day_id and s.owner_id = (select auth.uid())
    )
  );

-- profiles: one row per registered player, 1:1 with auth.users.
--
-- Username uniqueness/case-insensitivity comes from the `citext` type plus a
-- plain UNIQUE constraint — Postgres fundamentals, not a Supabase-specific
-- feature (see docs/PROPOSAL.md §4 and the earlier cost/architecture discussion).

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  username    citext not null,
  wins        integer not null default 0,
  losses      integer not null default 0,
  rating      integer not null default 1000,
  created_at  timestamptz not null default now(),

  constraint username_unique unique (username),
  -- Keep usernames predictable: 3-20 chars, letters/digits/underscore only.
  constraint username_format check (username ~ '^[A-Za-z0-9_]{3,20}$')
);

comment on table public.profiles is
  'Public player profile + stats. Live match state is NOT stored here — it lives '
  'in Colyseus room memory only; this table is written once a match ends (Phase 5).';

-- Row-Level Security: profiles are publicly readable (needed for username
-- search / opponent lookup) but a user may only ever write their own row.
alter table public.profiles enable row level security;

create policy "profiles are publicly readable"
  on public.profiles for select
  using (true);

create policy "users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- No delete policy: profiles are deleted only via the auth.users cascade above.

-- Auto-create a profile row the moment someone signs up, using the username
-- they supplied at signup (passed through `raw_user_meta_data`). Keeps the
-- client from having to make a second write right after registration.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (new.id, new.raw_user_meta_data ->> 'username');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

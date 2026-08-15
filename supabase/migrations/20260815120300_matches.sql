-- matches: persisted result of a completed Colyseus match (history + stats
-- source). Rows are written server-side once, when a MatchRoom ends (Phase 5)
-- — never by the client directly, hence no insert/update policy for users.

create table public.matches (
  id          uuid primary key default gen_random_uuid(),
  player_a    uuid not null references public.profiles (id) on delete cascade,
  player_b    uuid not null references public.profiles (id) on delete cascade,
  winner      uuid references public.profiles (id) on delete set null,
  started_at  timestamptz not null,
  ended_at    timestamptz not null default now(),
  score       jsonb,

  constraint players_differ check (player_a <> player_b)
);

comment on table public.matches is
  'One row per completed match, written by the Colyseus server (service role) '
  'after a MatchRoom ends. Never written directly by clients.';

create index matches_player_a_idx on public.matches (player_a);
create index matches_player_b_idx on public.matches (player_b);

alter table public.matches enable row level security;

-- Players can read matches they took part in (for match history screens).
-- Inserts/updates are done by the game server using the Supabase
-- service-role key, which bypasses RLS by design — no policy is needed
-- (and none is added) for writes from the client.
create policy "players can read their own matches"
  on public.matches for select
  using (auth.uid() = player_a or auth.uid() = player_b);

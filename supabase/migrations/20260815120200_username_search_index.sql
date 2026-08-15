-- Fast "find a user" search: trigram GIN index backs both
--   WHERE username ILIKE '%rocky%'   (substring search)
-- and prefix search, without a full table scan as the user base grows.
create index profiles_username_trgm_idx
  on public.profiles using gin (username gin_trgm_ops);

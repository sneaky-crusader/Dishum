-- Extensions Dishum relies on.
--
-- citext   : case-insensitive text, so "Rocky" and "rocky" collide as the
--            same username (the UNIQUE constraint in profiles.sql depends on this).
-- pg_trgm  : trigram indexing, so ILIKE '%substr%' username search stays fast
--            even as the profiles table grows (used in username_search.sql).
create extension if not exists citext;
create extension if not exists pg_trgm;

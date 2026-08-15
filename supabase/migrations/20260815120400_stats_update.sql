-- Applies a completed match's outcome to both players' win/loss/rating.
-- Called by the Colyseus server (service role) right after it inserts the
-- matches row — kept as one atomic function so a match's result is never
-- applied twice or left half-applied.
create function public.apply_match_result(
  p_winner uuid,
  p_loser  uuid,
  p_rating_delta integer default 15
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.profiles
    set wins = wins + 1, rating = rating + p_rating_delta
    where id = p_winner;

  update public.profiles
    set losses = losses + 1, rating = greatest(0, rating - p_rating_delta)
    where id = p_loser;
end;
$$;

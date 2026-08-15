extends RefCounted
## Supabase project connection details.
##
## The publishable key is safe to ship in the client by design — Supabase's
## own guidance is that this key is public; row-level security (see
## supabase/migrations/) is the actual security boundary, not key secrecy.
## The service_role/secret key must NEVER appear here — it belongs only to
## the Colyseus server (Phase 5, match-result writes).

const URL := "https://griglxichqiwdffajwtz.supabase.co"
const PUBLISHABLE_KEY := "sb_publishable_kj6ouUdNXZxDmQ90K3tjIQ_i3ST5h2y"

const AUTH_BASE := URL + "/auth/v1"

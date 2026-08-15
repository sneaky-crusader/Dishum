# Dishum

Minimalist real-time multiplayer boxing — one Godot 4 codebase for Android + iOS,
with an authoritative Colyseus game server and Supabase for accounts.

See [`docs/PROPOSAL.md`](docs/PROPOSAL.md) for the full architecture.

## Layout

```
client/    Godot 4 project (landscape, exports Android + iOS)
server/    Colyseus authoritative game server (Node.js + TypeScript)
supabase/  SQL migrations + RLS (added in Phase 1)
docs/      Proposal & design docs
app/       Legacy Android-only scaffold (to be removed once Godot export is verified)
```

## Run locally

**Client:** open the `client/` folder in Godot 4.7+ and press Play.

**Server:**
```
cd server
npm install
npm run dev      # hot-reload dev server on ws://localhost:2567
```

## Status

Phase 0 (foundations) — client + server scaffolds. Roadmap: `docs/PROPOSAL.md` §7.

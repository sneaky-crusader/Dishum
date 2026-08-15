// Dishum game server entrypoint.
// Phase 0: boots Colyseus with the MatchRoom registered. JWT auth (verifying
// Supabase tokens) and the matchmaking Lobby land in Phases 3–4.

import { Server } from "colyseus";
import { WebSocketTransport } from "@colyseus/ws-transport";
import { createServer } from "http";
import { MatchRoom } from "./rooms/MatchRoom.js";

const PORT = Number(process.env.PORT ?? 2567);

const gameServer = new Server({
  transport: new WebSocketTransport({ server: createServer() }),
});

// Direct-challenge and quick-match will both create/join "match" rooms.
gameServer.define("match", MatchRoom);

gameServer.listen(PORT).then(() => {
  console.log(`Dishum server listening on ws://localhost:${PORT}`);
});

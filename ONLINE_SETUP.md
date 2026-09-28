# Online Multiplayer Setup

1. Install Node.js on a VPS/cloud server.
2. Upload the `server` folder.
3. Run `npm install` then `npm start`.
4. Use `wss://YOUR-DOMAIN` in the mobile client in production.
5. The server protocol supports `create`, `join`, `start`, `roll`, `move`, and `chat`.

For production, add HTTPS/WSS, authentication, rate limiting, reconnect tokens, and a database for accounts/leaderboards.

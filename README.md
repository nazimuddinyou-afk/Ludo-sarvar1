# Ludo Multiplayer Server

## Local test

```bash
npm install
npm start
```

Server: `ws://127.0.0.1:8080`
Health: `http://127.0.0.1:8080/health`

## Docker

```bash
docker build -t ludo-server .
docker run -p 8080:8080 ludo-server
```

## Cloud deployment

The included `render.yaml` and `Dockerfile` can be used with a Docker-capable cloud host. After deployment, use the secure WebSocket URL (`wss://...`) in the Android client.

For production, add authentication, reconnect tokens, rate limiting, persistent accounts/leaderboards, TLS, and abuse protection.

import http from "node:http";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { registerSockets } from "./sockets/index.js";

const { app } = createApp();
const server = http.createServer(app);

registerSockets(server);

server.listen(env.API_PORT, () => {
  console.log(`SmartRes API listening on port ${env.API_PORT}`);
});


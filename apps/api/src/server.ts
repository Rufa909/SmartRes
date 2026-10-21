import http from "node:http";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { registerSockets } from "./sockets/index.js";

const { app } = createApp();
const server = http.createServer(app);

registerSockets(server);

server.listen(env.CUSTOMER_API_PORT, "0.0.0.0", () => {
  console.log(`SmartRes Customer API listening on port ${env.CUSTOMER_API_PORT}`);
});


import http from "node:http";
import { createApp } from "./app.js";
import { env } from "./config/env.js";
import { ensureCustomerSessions } from './customer-sessions.js';
import { db } from './infrastructure/database.js';

const { app } = createApp();
const server = http.createServer(app);

await ensureCustomerSessions(db);

server.listen(env.CUSTOMER_API_PORT, "127.0.0.1", () => {
  console.log(`SmartRes Customer API listening on port ${env.CUSTOMER_API_PORT}`);
});


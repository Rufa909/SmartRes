import type http from "node:http";
import { Server } from "socket.io";
import { domainEvents } from "../events/domain-events.js";

export function registerSockets(server: http.Server) {
  const io = new Server(server, {
    cors: {
      origin: "*"
    }
  });

  io.on("connection", (socket) => {
    socket.on("kds.join", () => socket.join("kitchen"));
    socket.on("dashboard.join", () => socket.join("dashboard"));
    socket.on("table.join", (tableId: string) => socket.join(`table:${tableId}`));
  });

  domainEvents.on("order.created", (payload) => {
    io.to("kitchen").to("dashboard").emit("order.created", payload);
  });

  domainEvents.on("order.status_updated", (payload) => {
    io.to("kitchen").to("dashboard").emit("order.status_updated", payload);
  });

  domainEvents.on("payment.confirmed", (payload) => {
    io.to("dashboard").emit("payment.confirmed", payload);
  });

  return io;
}

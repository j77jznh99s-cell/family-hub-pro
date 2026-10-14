#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { createBybitClient } from "./bybit.js";
import { checkCancel, checkClose, checkLeverage, checkOrder } from "./checks.js";
import { runGated } from "./gate.js";
import type { OrderRequest } from "./types.js";

const bybit = createBybitClient();

const server = new McpServer({
  name: "risk-gate",
  version: "1.0.0",
  description:
    "Holds Bybit trading credentials and approves or rejects every order. " +
    "This is the only tool set allowed to write to the exchange.",
});

// Every write goes through runGated (src/gate.ts): checks, then a
// "submitting" audit entry, then the exchange call, then the final audit
// entry. If the "submitting" entry cannot be written, nothing is sent, except
// for close_position and cancel_order (risk-reducing, blocked only by the kill
// switch), which warn and go ahead.

server.registerTool(
  "place_order",
  {
    title: "Place a risk-checked entry order",
    description:
      "Runs every risk check in order, then submits a market entry with an " +
      "attached stop loss and take profit. Rejections must never be retried " +
      "with different numbers; log the rejection and stop processing that action.",
    inputSchema: {
      symbol: z.string().describe("e.g. BTCUSDT"),
      side: z.enum(["long", "short"]),
      qty: z.number().positive(),
      stop: z.number().positive(),
      take_profit: z.number().positive(),
      price: z
        .number()
        .positive()
        .optional()
        .describe("Only for limit-style sanity checks; entries are market orders."),
    },
  },
  async (args) => {
    const req: OrderRequest = {
      symbol: args.symbol,
      side: args.side,
      qty: args.qty,
      stop: args.stop,
      take_profit: args.take_profit,
      price: args.price,
    };

    return runGated({
      tool: "place_order",
      request: req,
      check: () => checkOrder(req, bybit),
      submit: () => bybit.placeOrder(req),
      messages: {
        checkError: (msg) => `Gate error while checking order: ${msg}`,
        rejected: (reason) => `REJECTED (${reason}). Do not retry this action with different numbers.`,
        success: (resp) => `APPROVED and submitted. ${JSON.stringify(resp)}`,
        failure: (msg) => `Approved by the gate but the exchange rejected it: ${msg}`,
      },
    });
  }
);

server.registerTool(
  "close_position",
  {
    title: "Close an open position",
    description:
      "Reads the actual open position and submits an opposite-side market " +
      "order with reduceOnly set to true. Blocked only by the kill switch; " +
      "stays available past the daily loss cap since it is risk-reducing.",
    inputSchema: {
      symbol: z.string(),
    },
  },
  async ({ symbol }) =>
    runGated({
      tool: "close_position",
      request: { symbol },
      check: () => checkClose(),
      submit: () => bybit.closePosition(symbol),
      riskReducing: true,
      messages: {
        checkError: (msg) => `Gate error while checking close: ${msg}`,
        rejected: (reason) => `REJECTED (${reason}).`,
        success: (resp) => `Closed. ${JSON.stringify(resp)}`,
        failure: (msg) => `Close failed: ${msg}`,
      },
    })
);

server.registerTool(
  "set_leverage",
  {
    title: "Set symbol leverage",
    description: "Enforces the symbol leverage cap before forwarding the change.",
    inputSchema: {
      symbol: z.string(),
      leverage: z.number().positive(),
    },
  },
  async ({ symbol, leverage }) =>
    runGated({
      tool: "set_leverage",
      request: { symbol, leverage },
      check: () => checkLeverage(symbol, leverage),
      submit: () => bybit.setLeverage(symbol, leverage),
      messages: {
        checkError: (msg) => `Gate error while checking leverage: ${msg}`,
        rejected: (reason) => `REJECTED (${reason}). Do not retry with a different leverage value.`,
        success: (resp) => `Leverage set. ${JSON.stringify(resp)}`,
        failure: (msg) => `Set leverage failed: ${msg}`,
      },
    })
);

server.registerTool(
  "cancel_order",
  {
    title: "Cancel an open order",
    description: "Logs and forwards the cancellation. Blocked only by the kill switch.",
    inputSchema: {
      symbol: z.string(),
      order_id: z.string(),
    },
  },
  async ({ symbol, order_id }) =>
    runGated({
      tool: "cancel_order",
      request: { symbol, order_id },
      check: () => checkCancel(),
      submit: () => bybit.cancelOrder(symbol, order_id),
      riskReducing: true,
      messages: {
        checkError: (msg) => `Gate error while checking cancel: ${msg}`,
        rejected: (reason) => `REJECTED (${reason}).`,
        success: (resp) => `Cancelled. ${JSON.stringify(resp)}`,
        failure: (msg) => `Cancel failed: ${msg}`,
      },
    })
);

const transport = new StdioServerTransport();
await server.connect(transport);

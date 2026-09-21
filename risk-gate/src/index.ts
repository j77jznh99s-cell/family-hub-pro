#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { appendAudit } from "./audit.js";
import { createBybitClient } from "./bybit.js";
import { checkCancel, checkClose, checkLeverage, checkOrder } from "./checks.js";
import type { OrderRequest } from "./types.js";

const bybit = createBybitClient();

const server = new McpServer({
  name: "risk-gate",
  version: "1.0.0",
  description:
    "Holds Bybit trading credentials and approves or rejects every order. " +
    "This is the only tool set allowed to write to the exchange.",
});

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

    let result;
    try {
      result = await checkOrder(req, bybit);
    } catch (err) {
      appendAudit({
        tool: "place_order",
        request: req,
        checks: [],
        result: "error",
        reason: err instanceof Error ? err.message : String(err),
      });
      return {
        content: [{ type: "text", text: `Gate error while checking order: ${err instanceof Error ? err.message : String(err)}` }],
        isError: true,
      };
    }

    if (!result.approved) {
      appendAudit({
        tool: "place_order",
        request: req,
        checks: result.checks,
        result: "rejected",
        reason: result.reason,
      });
      return {
        content: [
          {
            type: "text",
            text: `REJECTED (${result.reason}). Do not retry this action with different numbers.`,
          },
        ],
      };
    }

    try {
      const exchangeResponse = await bybit.placeOrder(req);
      appendAudit({
        tool: "place_order",
        request: req,
        checks: result.checks,
        result: "approved",
        exchange_response: exchangeResponse,
      });
      return {
        content: [{ type: "text", text: `APPROVED and submitted. ${JSON.stringify(exchangeResponse)}` }],
      };
    } catch (err) {
      appendAudit({
        tool: "place_order",
        request: req,
        checks: result.checks,
        result: "error",
        reason: err instanceof Error ? err.message : String(err),
      });
      return {
        content: [{ type: "text", text: `Approved by the gate but the exchange rejected it: ${err instanceof Error ? err.message : String(err)}` }],
        isError: true,
      };
    }
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
  async ({ symbol }) => {
    const result = checkClose();
    if (!result.approved) {
      appendAudit({
        tool: "close_position",
        request: { symbol },
        checks: result.checks,
        result: "rejected",
        reason: result.reason,
      });
      return {
        content: [{ type: "text", text: `REJECTED (${result.reason}).` }],
      };
    }

    try {
      const exchangeResponse = await bybit.closePosition(symbol);
      appendAudit({
        tool: "close_position",
        request: { symbol },
        checks: result.checks,
        result: "approved",
        exchange_response: exchangeResponse,
      });
      return {
        content: [{ type: "text", text: `Closed. ${JSON.stringify(exchangeResponse)}` }],
      };
    } catch (err) {
      appendAudit({
        tool: "close_position",
        request: { symbol },
        checks: result.checks,
        result: "error",
        reason: err instanceof Error ? err.message : String(err),
      });
      return {
        content: [{ type: "text", text: `Close failed: ${err instanceof Error ? err.message : String(err)}` }],
        isError: true,
      };
    }
  }
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
  async ({ symbol, leverage }) => {
    const result = checkLeverage(symbol, leverage);
    if (!result.approved) {
      appendAudit({
        tool: "set_leverage",
        request: { symbol, leverage },
        checks: result.checks,
        result: "rejected",
        reason: result.reason,
      });
      return {
        content: [{ type: "text", text: `REJECTED (${result.reason}). Do not retry with a different leverage value.` }],
      };
    }

    try {
      const exchangeResponse = await bybit.setLeverage(symbol, leverage);
      appendAudit({
        tool: "set_leverage",
        request: { symbol, leverage },
        checks: result.checks,
        result: "approved",
        exchange_response: exchangeResponse,
      });
      return {
        content: [{ type: "text", text: `Leverage set. ${JSON.stringify(exchangeResponse)}` }],
      };
    } catch (err) {
      appendAudit({
        tool: "set_leverage",
        request: { symbol, leverage },
        checks: result.checks,
        result: "error",
        reason: err instanceof Error ? err.message : String(err),
      });
      return {
        content: [{ type: "text", text: `Set leverage failed: ${err instanceof Error ? err.message : String(err)}` }],
        isError: true,
      };
    }
  }
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
  async ({ symbol, order_id }) => {
    const result = checkCancel();
    if (!result.approved) {
      appendAudit({
        tool: "cancel_order",
        request: { symbol, order_id },
        checks: result.checks,
        result: "rejected",
        reason: result.reason,
      });
      return {
        content: [{ type: "text", text: `REJECTED (${result.reason}).` }],
      };
    }

    try {
      const exchangeResponse = await bybit.cancelOrder(symbol, order_id);
      appendAudit({
        tool: "cancel_order",
        request: { symbol, order_id },
        checks: result.checks,
        result: "approved",
        exchange_response: exchangeResponse,
      });
      return {
        content: [{ type: "text", text: `Cancelled. ${JSON.stringify(exchangeResponse)}` }],
      };
    } catch (err) {
      appendAudit({
        tool: "cancel_order",
        request: { symbol, order_id },
        checks: result.checks,
        result: "error",
        reason: err instanceof Error ? err.message : String(err),
      });
      return {
        content: [{ type: "text", text: `Cancel failed: ${err instanceof Error ? err.message : String(err)}` }],
        isError: true,
      };
    }
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);

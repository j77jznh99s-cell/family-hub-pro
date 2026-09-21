export type TradeSide = "long" | "short";
export type ExchangeSide = "Buy" | "Sell";

export interface OrderRequest {
  symbol: string;
  side: TradeSide;
  qty: number;
  stop?: number;
  take_profit?: number;
  /** Only present for limit entries; the strategy trades market entries only. */
  price?: number;
}

export interface Position {
  symbol: string;
  side: ExchangeSide;
  size: number;
  leverage: number;
  unrealisedPnl: number;
  markPrice: number;
}

export interface CheckStep {
  name: string;
  passed: boolean;
  detail?: Record<string, unknown>;
}

export interface GateResult {
  approved: boolean;
  reason: string;
  checks: CheckStep[];
}

export interface BybitClient {
  equityUsdt(): Promise<number>;
  pnlSinceMidnightUtc(): Promise<number>;
  markPrice(symbol: string): Promise<number>;
  leverage(symbol: string): Promise<number>;
  openPositions(): Promise<Position[]>;
  placeOrder(req: OrderRequest): Promise<unknown>;
  closePosition(symbol: string): Promise<unknown>;
  setLeverage(symbol: string, leverage: number): Promise<unknown>;
  cancelOrder(symbol: string, orderId: string): Promise<unknown>;
}

#!/usr/bin/env rdmd -main

import std.conv;
import std.format;
import std.stdio;

alias double DefaultPriceType;
alias ulong  TimeType;

enum OrderType {
    MARKET,
    LIMIT
};

enum TimeInForce {
    DAY,
    IOC,
    GTC
};

enum Side {
  BUY,
  SELL
};

struct OrderState(OrderType = Order!()) {
  alias typeof(OrderType.PriceType_t.init * 100.0) Volume;
  
  pragma( msg , Volume);
  ulong receivedTime;
  
  OrderType order;
  uint      cumQty = 0;
  Volume    volume = 0.0;

  this(OrderType o) {
    this.order = o;
    writefln("Volums is %s", volume);
  };
  
  auto avgPx() { return cumQty==0 ? 0.0 : volume / cumQty; };
  
  void handleExecution(ExecType)( ref ExecType exec) {
    cumQty += exec.qty;
    volume += exec.qty * exec.lastPx;
  };
};

struct Order(PriceType = DefaultPriceType) {
  alias PriceType PriceType_t;
  
  const int         orderQty;
  const OrderType   orderType;
  const TimeInForce timeInForce;
  const PriceType   limitPx;
};

struct Execution(PriceType = DefaultPriceType) {
  const int       qty;
  const PriceType lastPx;
};

alias Order!()      SimpleOrder;
alias OrderState!() SimpleOrderState;
alias Execution!()  SimpleExecution;

unittest {
  import std.stdio;
  
  Order!() x  = { 100, OrderType.MARKET, TimeInForce.DAY, 0.0  };
  Order!(int)    x2 = { 100, OrderType.MARKET, TimeInForce.DAY, 20   };
  SimpleOrder    x3 = { 100, OrderType.MARKET, TimeInForce.DAY, 20.0 };

  SimpleOrderState os = SimpleOrderState(x3);
  auto exec = SimpleExecution(25, 25.0);
  auto exec2 = SimpleExecution(30, 26.0);

  os.handleExecution( exec  );
  os.handleExecution( exec2 );

  writefln("Order is %s"     , x  );
  writefln("Order2 is %s"    , x2 );
  writefln("Order3 is %s"    , x3 );
  writefln("OrderState is %s", os );

  writefln("AvgPx is %s", os.avgPx());
};

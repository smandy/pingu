#!/usr/bin/env "rdmd -L--main"

import std.conv;
import std.format;
import std.stdio;
import std.range;
import std.functional;
import std.exception;

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

bool isBuy( Side s ) {
  final switch(s) {
  case Side.BUY:
    return true;
  case Side.SELL:
    return false;
  };
};

struct OrderState(OrderType = Order!()) {

  string toString() {
    return "OrderState("
      ~ to!string(order)
      ~ ",cumQty=" ~ to!string(cumQty)
      ~ ",volume=" ~ to!string(volume)
      ~ ",leavesQty=" ~ to!string(leavesQty)
      ~ ")";
  };
  
  alias typeof(OrderType.PriceType_t.init * 100.0) Volume;
  
  pragma(msg, Volume);
  
  OrderType order;
  uint      cumQty = 0;
  Volume    volume = 0.0;

  this(OrderType o) {
    this.order = o;
    writefln("Volums is %s", volume);
  };
  
  auto avgPx() { return cumQty==0 ? 0.0 : volume / cumQty; };
  
  auto leavesQty() { return orderQty - cumQty; }; // TODO cancel

  alias order this;
  
  void handleExecution(ExecType)(ExecType exec) {
    writeln("HandleExecution " ~ to!string(exec));
    cumQty += exec.qty;
    volume += exec.qty * exec.lastPx;
  };
};

immutable struct Order(PriceType = DefaultPriceType) {
  alias PriceType PriceType_t;
  ulong receivedTime;
  Side        side;
  int         orderQty;
  OrderType   orderType;
  TimeInForce timeInForce;
  PriceType   limitPx;
};

struct Execution(PriceType = DefaultPriceType) {
  const int       qty;
  const PriceType lastPx;
};

alias Order!()      SimpleOrder;
alias OrderState!() SimpleOrderState;
alias Execution!()  SimpleExecution;
alias OrderManager!() SimpleOrderManager;

size_t getTransitionIndex(alias test, V, Range)(Range xs, V v) {
  size_t first = 0, count = xs.length;
  while (count > 0) {
    immutable step = count / 2, it = first + step;
    if (!binaryFun!test(xs[it], v)) {
      first = it + 1;
      count -= step + 1;
    } else {
      count = step;
    }
  }
  return first;
}

enum buyPred  = "a.limitPx > b.limitPx && a.receivedTime < b.receivedTime";
enum sellPred = "a.limitPx < b.limitPx && a.receivedTime < b.receivedTime";

mixin template DefaultHandling() {
  void handleExecution(ExecType)(ExecType exec) {
    writefln("Handle execution %s", exec);
  };
};

struct OrderManager(OrderType  = SimpleOrder,
                    OrderState = OrderState!OrderType,
                    alias OrderHandling = DefaultHandling) {
  OrderState[] buys;
  OrderState[] sells;

  mixin OrderHandling!();

  alias PriceType_t = OrderType.PriceType_t;

  void onOrder(OrderType order) {
    //myClock++;
    auto side = order.side.isBuy() ? buys : sells;
    if (order.side.isBuy) {
      if (sells.empty || order.limitPx < side[0].limitPx) {
        //Not crossing buy - go onto book
        size_t idx = side.getTransitionIndex!buyPred(order);
        writefln("Adding to side %s", idx);
        (order.side.isBuy() ? buys : sells) = side[0..idx] ~ OrderState(order) ~ side[idx..$];
        writefln("siide=%s buys=% sells=%s", side, buys, sells);
      } else {
        // TODO aggressive buy
      };
    } else {
      // enforce( !order.side.isBuy() , "Logic error");
      writefln("buys is %s", buys);
      if ( buys.empty || order.limitPx > buys[0].limitPx ) {
        // TODO Not crossing sell - go onto book
        writefln("Not Crossing sell");
      } else {
        auto oppositeSide = order.side.isBuy() ? sells : buys;
        writefln("Crossing sell sidelength=%s", oppositeSide.length);
        enforce( !order.side.isBuy(), "Logic error");
        uint fillRemainQty = order.orderQty;
        auto fillIdx = 0;
        auto totalFillQty = 0;
        typeof( PriceType_t.init * 0 ) totalFillVolume = 0;
        auto  fullFillIdx = 0;
        int[] fills;
        while (fillIdx < oppositeSide.length && fillRemainQty>0) {
          auto matchOrder = oppositeSide[fillIdx];
          uint fillQty;
          if (matchOrder.orderQty > fillRemainQty) {
            fillQty = fillRemainQty;
          } else {
            fullFillIdx++;
            fillQty = matchOrder.orderQty;
          };
          fills ~= fillQty;
          fillRemainQty   -= fillQty;
          totalFillQty    += fillQty;
          totalFillVolume += fillQty * matchOrder.limitPx;
          fillIdx++;
        }
        writefln("FillIdx %s", fillIdx);
        for (int i = 0;i< fillIdx;++i) {
          buys[i].handleExecution( SimpleExecution( fills[i], buys[i].limitPx) );
        };
        buys = buys[fullFillIdx..$];
        writefln("Buys is now %s", buys);
        handleExecution( SimpleExecution( totalFillQty, totalFillVolume / totalFillQty));
        if (buys.empty && fillRemainQty >0) {
        };
      }
    }
  }
}

void main() {
  writeln("Doit");

  if (false) {
    SimpleOrderManager om;
    ulong clock;
    om.onOrder( SimpleOrder(clock, Side.BUY, 100, OrderType.LIMIT, TimeInForce.DAY, 20.0)  );
    om.onOrder( SimpleOrder(clock, Side.BUY, 100, OrderType.LIMIT, TimeInForce.DAY, 21.0)  );
    om.onOrder( SimpleOrder(clock, Side.SELL, 200, OrderType.LIMIT, TimeInForce.DAY, 20.0) );
  }


  
  
  {

    struct MyHandler {
      void handleExecution(ExecType)(ExecType exec) {
        writefln("Handle Execution %s" , exec);
      };
    };
    
    MyHandler handler;
    
    SimpleOrderManager om;
    ulong clock;
    om.onOrder( SimpleOrder(clock, Side.BUY, 25, OrderType.LIMIT, TimeInForce.DAY, 20.0) );
    om.onOrder( SimpleOrder(clock, Side.BUY, 25, OrderType.LIMIT, TimeInForce.DAY, 21.0) );
    om.onOrder( SimpleOrder(clock, Side.SELL, 100, OrderType.LIMIT, TimeInForce.DAY, 20.0));
  }

};

unittest {
};

unittest {
  import std.stdio;
  ulong clock;
  
  immutable Order!() x  = { clock++, Side.BUY, 100, OrderType.MARKET, TimeInForce.DAY, 0.0  };
  Order!(int)        x2 = { clock++, Side.BUY, 100, OrderType.MARKET, TimeInForce.DAY, 20   };
  SimpleOrder        x3 = { clock++, Side.BUY, 100, OrderType.MARKET, TimeInForce.DAY, 20.0 };

  SimpleOrderState os = SimpleOrderState(x3);
  auto exec           = SimpleExecution(25, 25.0);
  auto exec2          = SimpleExecution(30, 26.0);
  
  os.handleExecution( exec  );
  os.handleExecution( exec2 );

  writefln("Order is %s"     , x  );
  writefln("Order2 is %s"    , x2 );
  writefln("Order3 is %s"    , x3 );
  writefln("OrderState is %s", os );
  writefln("AvgPx is %s", os.avgPx());
};

#!/usr/bin/env "rdmd -L--main"

import std.conv;
import std.format;
import std.stdio;
import std.range;
import std.functional;
import std.exception;
import std.traits;

alias double DefaultPriceType;
alias ulong  DefaultOrderIdType;
alias ulong  DefaultTimeType;

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

// Use me with UFCS
bool isBuy( Side s ) {
  final switch(s) {
  case Side.BUY:
    return true;
  case Side.SELL:
    return false;
  };
};

template IsOrder(T) {
  enum hasQty   = __traits(compiles, (T t) { return t.orderQty > 10; }   );
  enum hasPrice = __traits(compiles, (T t) { return t.limitPx  > 20.0; } );
  enum hasSide  = __traits(compiles, (T t) { return t.side == Side.BUY; } );

  enum IsOrder = {
    //pragma(msg, hasQty);
    //pragma(msg, hasQty);
    return hasQty && hasPrice && hasSide;
  }();
}

pragma(msg, "Size of simpleorder is " , SimpleOrder.sizeof);

struct OrderState(OrderType = SimpleOrder) if (IsOrder!OrderType) {
  string toString() {
    return "OrderState("
      ~ to!string(order)
      ~ ",cumQty=" ~ to!string(cumQty)
      ~ ",volume=" ~ to!string(volume)
      ~ ",avgPx=" ~ to!string(avgPx)
      ~ ",leavesQty=" ~ to!string(leavesQty)
      ~ ")";
  };
  
  alias typeof(OrderType.PriceType_t.init * 100.0) Volume;
  
  //pragma(msg, Volume);
  
  OrderType order;
  uint      cumQty = 0;
  Volume    volume = 0.0;

  this(OrderType o) {
    this.order = o;
  };
  
  @property auto avgPx() { return cumQty==0 ? 0.0 : volume / cumQty; };
  
  @property auto leavesQty() { return orderQty - cumQty; }; // TODO cancel

  alias order this;
  
  void handleExecution(ExecType)(ExecType exec) {
    cumQty += exec.qty;
    volume += exec.qty * exec.lastPx;
  };
};

immutable struct Order(PriceType   = DefaultPriceType,
                       OrderIdType = DefaultOrderIdType ) {
  alias PriceType   PriceType_t;
  alias OrderIdType OrderIdType_t;
  ulong       receivedTime;
  OrderIdType orderId;
  uint        secId;
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

//pragma(msg, "IsOrder ", IsOrder!SimpleOrder);

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

mixin template NoopHandling() {
  void handleExecution(ExecType)(ExecType exec) {
    // NOOP
  };
};

mixin template VerboseHandling() {
  void handleExecution(ExecType)(ExecType exec) {
    writefln("Execution %s", exec);
  };
};

version(unittest) {
  alias DefaultHandling = VerboseHandling;
} else {
  alias DefaultHandling = NoopHandling;
 };


struct OrderManager(OrderType  = SimpleOrder,
                    OrderState = OrderState!OrderType,
                    alias OrderHandling = DefaultHandling) {
  OrderState[] buys;
  OrderState[] sells;

  mixin OrderHandling!();
  alias PriceType_t = OrderType.PriceType_t;


  version (diagnostic) {
    void dump() {
      writeln("\nBUYS\n########################################");
      foreach( buy ; buys ) {
        writeln(buy);
      };
      
      writeln("\nSELLS\n########################################");
      foreach( sell ; sells ) {
        writeln(sell);
      };
    };
  };
  
  void onOrder(OrderType order) {
    //myClock++;
    auto side = order.side.isBuy() ? buys : sells;

    if (order.side.isBuy) {
      if (sells.empty || order.limitPx < side[0].limitPx) {
        //Not crossing buy - go onto book
        size_t idx = side.getTransitionIndex!buyPred(order);
        (order.side.isBuy() ? buys : sells) = side[0..idx] ~ OrderState(order) ~ side[idx..$];
      } else {
        // TODO aggressive buy
      };
    } else {
      // enforce( !order.side.isBuy() , "Logic error");
      // writefln("buys is %s", buys);
      if ( buys.empty || order.limitPx > buys[0].limitPx ) {
        (order.side.isBuy() ? buys : sells) ~= OrderState(order);
        // TODO Not crossing sell - go onto book
        //writefln("Not Crossing sell");
      } else {
        auto oppositeSide = order.side.isBuy() ? sells : buys;
        //writefln("Crossing sell sidelength=%s", oppositeSide.length);
        //enforce( !order.side.isBuy(), "Logic error");
        uint fillRemainQty = order.orderQty;
        auto fillIdx = 0;
        auto totalFillQty = 0;
        typeof( PriceType_t.init * 0 ) totalFillVolume = 0;
        auto  fullFillIdx = 0;
        int[] fills;
        while ( fillIdx < oppositeSide.length && fillRemainQty > 0 ) {
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
        //writefln("FillIdx %s", fillIdx);
        for (int i = 0;i< fillIdx;++i) {
          buys[i].handleExecution( SimpleExecution( fills[i], buys[i].limitPx) );
        };
        buys = buys[fullFillIdx..$];
        //writefln("Buys is now %s", buys);
        auto exec = SimpleExecution( totalFillQty, totalFillVolume / totalFillQty);
        handleExecution(exec );
        if (buys.empty && fillRemainQty >0) {
          buys ~= OrderState(order);
          buys[0].handleExecution(exec);
        };
      }
    }
  }
}

version (unittest) {
  mixin template SimpleBuyTest() {
    enum name = "SimpleBuyTest";
    
    void start() {
      om.onOrder( SimpleOrder(clock, orderId++, SECID, Side.BUY, 25, OrderType.LIMIT,   TimeInForce.DAY, 20.0) );
    };
  };

  mixin template CaseTwo() {
    enum name = "CaseTwo";
    void start() {
      seed( 100 , Side.BUY  , 20.0);
      seed( 1000, Side.BUY  , 21.0);
      seed( 200 , Side.SELL , 20.0);
      
      enforce( om.sells.empty, "Logic error");
      enforce( om.buys.length == 1 );
      auto theBuy = om.buys[0];
      enforce( theBuy.leavesQty == 900 , "Incorrect leaves");
      enforce( theBuy.avgPx     == 21.0, "Incorrect avgPx");
      enforce( theBuy.cumQty    == 100 , "Incorrect avgPx ");
    };
  };

  mixin template CaseThree() {
    enum name = "CaseThree";
    void start() {
      seed( 100 , Side.BUY  , 20.0);
      seed( 100 , Side.BUY  , 21.0);
      seed( 200 , Side.SELL , 21.0);
      
      enforce( om.sells.length == 1 );
      enforce( om.buys.length  == 1 );
      auto theBuy = om.buys[0];
      enforce( theBuy.leavesQty == 1000 , "Incorrect leaves");
      enforce( theBuy.cumQty    == 0 , "Incorrect avgPx ");
    };
  };

  
  struct SimpleTest(alias TestType) {
    SimpleOrder.OrderIdType_t orderId;
    alias SimpleOrder.PriceType_t PriceType;
    
    auto SECID = 66;
    SimpleOrderManager om;
    ulong clock;
    mixin TestType!();

    void seed( int qty, Side side, PriceType px) {
      om.onOrder( SimpleOrder(clock, orderId++, SECID, side, qty, OrderType.LIMIT, TimeInForce.DAY, px)  );
    };

    void run() {
      writefln("Running Test Case %s", name);
      writeln("=====================");
      
      start();
      om.dump();
    };
  };
}

unittest {
  SimpleTest!CaseTwo().run();
  SimpleTest!SimpleBuyTest().run();
  SimpleTest!CaseThree().run();
};


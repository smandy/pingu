#!/usr/bin/env rdmd

import std.stdio;
import std.range;
import std.algorithm;

import std.functional : binaryFun;

struct SimpleOrder {
  ulong  time;
  double price;
};

unittest {
  SimpleOrder[] orders;
  ulong counter;
  void  onOrder( SimpleOrder o) {
    size_t idx = getTransitionIndex!buyPred(o);
    //writefln("Idx is %s", idx);
    orders = orders[0..idx] ~ [o] ~ orders[idx..$]; //assumeSorted([o]); // .assumeSorted;
    writefln("Orders is %s", orders);
  };
  
  auto idx = 0;
  
  auto orders2 = [SimpleOrder(idx++, 100.0),
                  SimpleOrder(idx++, 100.0),
                  SimpleOrder(idx++, 100.0),
                  SimpleOrder(idx++, 99.0),
                  SimpleOrder(idx++, 101.0),
                  SimpleOrder(idx++, 100.0)];
  
  foreach ( ref o ; orders2) {
    onOrder(o);
  };
  
  orders2.sort!buyPred;
  writefln("Resorted is now %s", orders2);
};

#!/usr/bin/env rdmd -main

import Order;

struct OrderManager(OrderType = SimpleOrder,
                    OrderState = OrderState!OrderType) {
  OrderState[] buys;
  OrderSTate[] sells;

  void onOrder(ref OrderType order) {
    
  };
};



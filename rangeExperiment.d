#!/usr/bin/env rdmd

import std.stdio;

import std.range;

void main() {
  auto xs = [1,2,3,4,5];
  writefln("Empty %s", xs.empty);
};

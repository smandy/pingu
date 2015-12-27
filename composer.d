
import std.functional;
import std.stdio;
import std.range;
import std.algorithm;

void main() {
  iota(1,10)
    .map!( compose!("a+1", "a*2", "a-5", "a % 10") )
    .writeln;
  //iota(1,10)
};

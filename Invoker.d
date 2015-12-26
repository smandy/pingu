import std.conv;
import std.stdio;
import std.traits;
import std.algorithm;
import std.format;
import std.array;

template Invoker(V,TS...) {
  auto Invoker(V v) {
    static if ( TS.length > 0) {
      auto nextArg = TS[0](v);
      alias RetType = typeof(TS[0](v));
      return Invoker!( RetType , TS[1..$] )( nextArg);
    } else {
      return v;
    };
  };
};

void main() {
  auto x = Invoker!(string, doit, boit, goit)("Woot");
  writeln(x);
};

string[] doit(string x) {
  return x.map!( (dchar x) { return format("%s%s", x , x) ; } ).array;
};

auto boit(ReturnType!doit s) {
  return s.map!( x => x.length ).array;
};

string goit( ReturnType!boit s) {
  return "Goit(" ~ to!string(s) ~ ")";
};



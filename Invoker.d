import std.conv;
import std.stdio;
import std.traits;
import std.algorithm;
import std.format;
import std.array;

template Invoker(TS...) {
  auto Invoker(V)( V v ) {
    return impl!(V, TS)(v);
  }

private:
  auto impl(V, TS...)(V v) {
    static if ( TS.length > 1) {
      auto nextArg = TS[0](v);
      return impl!( typeof(nextArg), TS[1..$] )( nextArg);
    } else {
      return v;
    }
  }
}

void main() {
  auto x = Invoker!(doit, boit, goit)("Woot");
  writeln(x);
}

auto doit(string x) {
  return x.map!( (dchar x) { return format("%s%s", x , x) ; } ).array;
}

auto boit(ReturnType!doit s) {
  return s.map!( x => x.length ).array;
}

auto goit( ReturnType!boit s) {
  return "Goit(" ~ to!string(s) ~ ")";
}

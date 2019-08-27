
#
# This is a set of *minimal* self-hosted test cases to aid in verifying step by step that 
# core parts of the compiler itself acts the same when run under MRI as when run by itself
# It on purpose does not use any unit testing framework in order to minimize dependencies,
# given that as of writing the commpiler is by no means complete.
#
# It is also not meant to be a comprehensive set of test cases, but to test just whatever
# is needed to ensure the compiler can compile itself and a more reasonable test suite.
#
# That means avoiding all "magic".
#
# Run with:
#
#    ruby -I . test/selftest.rb
#
# Compile and run with:
#
#    ./compile test/selftest.rb -I.
#    /tmp/selftest
#

# FIXME: At some point globals seems to have broken.
# Don't output PASS's
# $quiet = true

require 'scanner'
require 'parserbase'
require 'sym'
require 'atom'
require 'tokens'
require 'quoted'
require 'sexp'

require 'regalloc'
require 'function'

require 'utils'
require 'pp'
require 'treeoutput'

require 'tokenizeradapter'
require 'operators'

require 'parser'
require 'shunting'
require 'register'
require 'iooutput'
require 'arrayoutput'

require 'regalloc'
require 'emitter'

require 'scope'
require 'globalscope'
require 'classcope'
require 'funcscope'
require 'sexpscope'
require 'localvarscope'
require 'print_sexp'
require 'vtableoffsets'

require 'ast'
#require 'value'
require 'compiler'

class MockIO
  def initialize str
    @str = str
    @pos = 0
  end

  def to_str
    @str
  end

  def getc
    ch = @str[@pos]
    @pos += 1
    ch
  end
end

# FIXME: The 27.chr is a workaround for parser bug
# with \e
def col(num)
  "#{27.chr}[3#{num.to_s}m"
end

def msg_pass(message, right)
#  if !$quiet
#    puts "#{col(2)}PASS#{col(7)}: #{message} [expected/got #{right.inspect}]"
#  end
end

def msg_fail(message, left,right)
  puts "#{col(1)}FAIL#{col(7)}: #{message} [expected #{right.inspect}, got #{left.inspect}]"
end

def expect_eq(left, right, message)
  if left == right
    msg_pass(message, right)
  else
    msg_fail(message, left, right)
  end
end

def test_fixnum
  expect_eq((40 % 10).inspect, "0", "40 % 10 == 0")
  expect_eq(4096.to_s(10), "4096", "4096.to_s(10) => '4096'")
  expect_eq(4096.inspect, "4096", "4096.inspect => '4096'")
  expect_eq("-4".to_i.to_s,"-4", "Converting -4 from a string to Fixnum and back")
  expect_eq((-4).to_s,"-4", "Converting -4 to a string")

  expect_eq(4 <=> 3, 1, "4 <=> 3 should return 1")
end

def test_symbol
  expect_eq(:foo == :foo, true, "Same symbol should match with #==")
  expect_eq(:foo === :foo, true, "Same symbol should match with #===")
  expect_eq(:foo.eql?(:foo), true, "Same symbol should match with #eql?")
  expect_eq(:foo != :foo, false, ":foo != :foo => false")
  expect_eq(:foo != :bar, true, ":foo != :bar => true")
end

def test_array
  a = []

  expect_eq(a.length, 0, "#length on empty array")

  b = [42,43,44]
  expect_eq(b.length, 3, "#length on 3-element array")

  e = b.delete_at(1)
  expect_eq(e, 43, "[42,43,44].delete_at(1) should return 43")
  expect_eq(b.inspect, "[42, 44]", "[42, 44].inspect should return [42, 44]")
  expect_eq(b.length, 2, "#length after [42,43,44].delete_at(1)")
  e = b.delete_at(0)
  expect_eq(e, 42, "[42,44].delete_at(0) should return 42")
  expect_eq(b.length, 1, "#length after [42,44].delete_at(0)")
  e = b.delete_at(0)
  expect_eq(e, 44, "[44].delete_at(0) should return 44")
  expect_eq(b.length, 0, "#length after [44].delete_at(0)")

  expect_eq([32].member?(32),true, "member? should return true if an element exists in the array")

  b = [42,43]
  expect_eq(b[0], 42, "b=[42,43]; b[0] should return 42")
  expect_eq(b[-1], 43, "b=[42,43]; b[-1] should return 43")
  expect_eq(b[1..-1].inspect, [43].inspect, "b=[42,43]; b[1..-1] should return [43]")

  b = [1,2,3,4]
  expect_eq(b.reverse.inspect, [4,3,2,1].inspect, "Array#reverse should reverse an array")

  # FIXME: Inlining this into the expect_eq() call causes seg-fault.
  part = [42,2,5,1].partition {|v| v > 4}
  expect_eq(part.inspect, [[42,5], [2,1]].inspect, "Array#partition should split an array in two based on provided block")

  #expect_eq([42,2,3,1].sort,     [1,2,3,42], "Array#sort")
  res = [42,2,3,1].sort_by {|v| v }
  expect_eq(res.inspect, [1,2,3,42].inspect , "Array#sort_by (ascending)")
  # FIXME: The below fails due to "-"
#  res = [42,2,3,1].sort_by {|v| -v }
#  expect_eq(res, [42,3,2,1] , "Array#sort_by (descending)")

  expect_eq(42 <=> 2, 1, "Fixnum#<=>(42,2)")
  expect_eq(42 <=> 3, 1, "Fixnum#<=>(42,3)")
  expect_eq(42 <=> 1, 1, "Fixnum#<=>(42,1)")
  expect_eq(2 <=> 3, -1, "Fixnum#<=>(2,3)")
  expect_eq(2 <=> 2, 0, "Fixnum#<=>(2,2)")
  expect_eq(3 <=> 1, 1, "Fixnum#<=>(3,1)")

  #  ary = [42,2,3,1]
  # FIXME: This causes a parse/compilation error:
  #  res = ary.partition {|e| (e <=> 2) > 0 }
  #  expect_eq(res.inspect, "[[42, 3], [2, 1]]", "partition")

  res = [42,2,3,1].sort
  expect_eq(res.inspect, [1,2,3,42].inspect , "Array#sort (ascending)")

  res = Array(42)
  expect_eq(res.inspect,"[42]", "Array(42) should return [42]")

  expect_eq([0,1,2,3,4].insert(2,42).inspect, "[0, 1, 42, 2, 3, 4]", "Array#insert with a positive offset should insert its argument *before* the value at the offset")
  expect_eq([0,1,2].insert(4,42).inspect, "[0, 1, 2, nil, 42]", "Array#insert with an offset larger than the array should cause 'nil's to be inserted to expand the array accordingly")
  expect_eq([0,1,2].insert(-1,42).inspect, "[0, 1, 2, 42]", "Array#insert with -1 as offset is the same as appending an entry at the end")
  expect_eq([0,1,2].insert(-2,42).inspect, "[0, 1, 42, 2]", "Array#insert with a negative offset is the same as counting that many places from the right, and then inserting the entry *after* that position")

  # Test the extensions to Array used by the compiler:
  a = [:stackframe]
  expect_eq(a.inspect, "[:stackframe]", "Array with a single symbol")
  expect_eq(a[1].inspect, "nil", "[:stackframe][1] should return nil")
  expect_eq(a[-1].inspect, ":stackframe", "[:stackframe][-1] should return :stackframe")
  expect_eq(a[1..-1].inspect, "[]", "[:stackframe][1..-1] should return []")

  expect_eq(([:a] - [:a]).inspect, "[]", "Subtracting identical arrays should return []")
  expect_eq(([:a, :b, :c] - [:b]).inspect, "[:a, :c]", "Subtracting part of an array should return the rest")

  expect_eq([:a, :b, :c].zip(1..3).inspect, "[[:a, 1], [:b, 2], [:c, 3]]", "Array#zip should merge the array with an enumerable")
end

def test_set
  s = Set.new
  s << :a
  s << :b
  s << :c
  a = [:foo, :a]

  expect_eq((s - a).inspect, "#<Set: {:b, :c}>", "Subtracting an array from a Set")
  c = [:c]
  expect_eq((s - a - c).inspect, "#<Set: {:b}>", "Chained subtration of arrays from a Set")
end

def test_hash

  d = Hash.new(42)
  expect_eq(d[1],42, "Verifying that Hash returns default specified default value for unknown key")

  #d[1] += 1
  #expect_eq(d[1],43, "Incrementing default value")

end


# Test our own Mock first...
#
def test_mockio
  m = MockIO.new("")
  expect_eq(m.is_a?(File), false, "mockio.is_a?(File)")
  expect_eq(File.file?(m), false, "File.file?(MockIO.new")
end

def test_scannerstring
  s = Scanner::ScannerString.new("Test")

  expect_eq(s, "Test", "ScannerString and String with same contents")
end

def test_scanner_basics
  io = MockIO.new("This is a test")
  s = Scanner.new(io)

  expect_eq(s.filename,"<stream>", "Scanner#filename for non-file IO")

  expect_eq(s.peek, ?T, "scanner.peek on 'This is a test'")
  expect_eq(s.get, "T", "scanner.get on 'This is a test'")
  expect_eq(s.get, "h", "scanner.get with 'his is a test' remaining")
  s.unget("h");
  expect_eq(s.get, "h", "scanner.get with 'his is a test' remaining after unget")

  expect_eq(s.expect("is"),"is", "scanner.expect('is') with 'is a test' remaining")

  s.expect("a test")
  expect_eq(s.expect("x"), false, "scanner.expect('x') after having consumed the whole string should return nil")
end


def test_parserbase_basics
  io = MockIO.new("This is a test")
  s  = Scanner.new(io)
  pb = ParserBase.new(s)

  expect_eq(pb.expect("This"),"This", "parser.expect('This')")
  expect_eq(pb.ws,nil, "Skip whitespace")
  expect_eq(pb.expect("is"),"is", "parser.expect('is') after skipping whitespace")
end

def test_sym
  io = MockIO.new(":sym @ivar $global $var42 @with_underscore")
  s  = Scanner.new(io)

  expect_eq(Tokens::Sym.expect(s), :":sym", "Parse symbol :sym")
end

def test_atom
  io = MockIO.new(":sym @ivar $global $var42 @with_underscore")
  s  = Scanner.new(io)

  expect_eq(Tokens::Atom.expect(s), :":sym", "Parse atom :sym")
end

# The full version of respond_to? is a pre-requisite for the s-exp parsing
def test_respond_to
  expect_eq(Object.new.respond_to?(:foo), false, "Object.new.respond_to?(:foo)?")
  expect_eq(Object.new.respond_to?(:inspect), true, "Object.new.respond_to?(:inspect)?")
end

def mock_scanner(str)
  io = MockIO.new(str)
  Scanner.new(io)
end

def test_sexp_basics
  s  = mock_scanner("%s(this is a test)")
  sx = SEXParser.new(s)

  tree = sx.parse

  expect_eq(tree.inspect, "[:sexp, [:this, :is, :a, :test]]", "Parsing %s(this is a test)")

  tree = SEXParser.new(mock_scanner("%s(index self -4)")).parse
  expect_eq(tree.inspect, "[:sexp, [:index, :self, -4]]", "Parsing %s(index self -4)")
end

def test_tokenizer
  s  = mock_scanner(":sym test 123 'foo' +")
  t = Tokens::Tokenizer.new(s,nil)

  ar = []
  t.each do |token,oper|
    ar << [token,oper]
  end

  s = mock_scanner("def foo; end")
  t = Tokens::Tokenizer.new(s,nil)
  while tok = t.get and tok[0]
    ar << tok
  end
end

def test_methodname_tokenizer
  s = mock_scanner("__flag=x")
  expect_eq(Tokens::Methodname.expect(s).inspect, ":__flag=", "__flag= is a legal method name")
end

def mock_shunting(str)
  s = mock_scanner(str)
  OpPrec.parser(s, nil)
end


def test_shunting
  expect_eq(mock_shunting("5 + 1").parse.inspect, "[:+, 5, 1]", "Shunting 1")
  expect_eq(mock_shunting("5 + y").parse.inspect, "[:+, 5, :y]", "Shunting 2")
  expect_eq(mock_shunting("5 + 1 * 2").parse.inspect, "[:+, 5, [:*, 1, 2]]", "Shunting 3")
end


def mock_parse(str, require_core = false)
  parser = Parser.new(mock_scanner(str))
  parser.parse(require_core)
end

def test_exp(exp, result)
  m = mock_parse(exp).inspect
  expect_eq(m, result, "Parsing '#{exp}' with the full parser")
end

def test_parser
  test_exp("%s(this is a test)", "[:do, [:sexp, [:this, :is, :a, :test]]]")
  test_exp("5 + a", "[:do, [:+, 5, :a]]")
  test_exp("puts 'Hello World'", "[:do, [:call, :puts, [\"Hello World\"]]]")
  test_exp("def foo; end", "[:do, [:defm, :foo, [], []]]")
  test_exp("def foo; puts 'Hello World'; end", "[:do, [:defm, :foo, [], [[:call, :puts, [\"Hello World\"]]]]]")
  test_exp("e[i]", "[:do, [:callm, :e, :[], [:i]]]")
  test_exp("e[i] = E[:foo]", "[:do, [:callm, :e, :[]=, [:i, [:callm, :E, :[], [:\":foo\"]]]]]")
  test_exp('"\e"',"[:do, \"\\\\e\"]")
  test_exp("Set[* e[2].to_a]","[:do, [:callm, :Set, :[], [[:splat, [:callm, [:callm, :e, :[], [2]], :to_a]]]]]")
  test_exp("def foo; name.gsub(foo.bar) { }; end ","[:do, [:defm, :foo, [], [[:callm, :name, :gsub, [[:callm, :foo, :bar]], [:proc]]]]]")
  test_exp('STDERR.puts "defm: #{args.inspect}"', "[:do, [:callm, :STDERR, :puts, [[:concat, \"defm: \", [:callm, :args, :inspect]]]]]")
  test_exp("self.== other","[:do, [:callm, :self, :==, :other]]")

  # Testing basic operator associativity.
  test_exp("a - b - c","[:do, [:-, [:-, :a, :b], :c]]")
  test_exp("a + b + c","[:do, [:+, [:+, :a, :b], :c]]")
  test_exp("a * b * c","[:do, [:*, [:*, :a, :b], :c]]")
  test_exp("a / b / c","[:do, [:/, [:/, :a, :b], :c]]")

  test_exp("1..x.size","[:do, [:range, 1, [:callm, :x, :size]]]")
end

def test_destructuring
  test_exp("a,b = [42,123]", "[:do, [:assign, [:destruct, :a, :b], [:array, 42, 123]]]")
end

def test_depth_first
  prog = mock_parse("a = 42")
  prog.depth_first(:defm) do |n|
    msg_fail("Testing depth_first","not to get here", "here")
  end
  msg_pass("depth_first","to get here")

  prog = [:if, [:a, :b], [:do, :c]]
  out = []
  prog.depth_first do |e|
    out << e
  end
  expect_eq(out.inspect, [[:if, [:a, :b], [:do, :c]], [:a, :b], [:do, :c]].inspect, "#depth_first should descent into each array")
end

def mock_preprocess(exp)
  prog = mock_parse(exp, false)
  #e = Emitter.new
  #c = Compiler.new(e)
  #c.preprocess(prog)
  #c.compile(prog)
end

include AST

def test_compiler
  e = Emitter.new
  c = Compiler.new(e)
  exp = [E[:assign, :foo, [:array, [:sexp, [:call, :__get_fixnum, 1]]]], 
        [:callm, :foo, :each, [], E[:proc, [:e], [:arg, [:call, :puts, [:arg]]]]]]
  args = Set.new
  args << :arg
  scopes = [args]

  r = c.find_vars(exp,scopes,Set.new, Hash.new(0))
  expect_eq("[[:foo], #<Set: {:arg}>]", r.inspect, "Compiler#find_vars")

  prog = mock_parse("def __flag=x\n    42\n  end\n")
  expect_eq(prog.inspect, "[:do, [:defm, :__flag=, [:x], [42]]]", "Parse 'def __flag=(x)' without leaving out the =")
  # FIXME: The way this gets rewritten is awful, but this test does cover the current correct behaviour
  prog = mock_parse("\"\#{'foo'}\#{'bar'}\"")
  c = Compiler.new(e)
  c.rewrite_concat(prog)
  expect_eq(prog.inspect, [:do, [:callm, [:callm, [:callm, [:callm, "", :to_s], :concat, [[:callm, "foo", :to_s]]], :concat, [[:callm, "", :to_s]]], :concat, [[:callm, "bar", :to_s]]]].inspect, "concat => callm")
  prog = mock_parse('
  if a < 2
    STDERR.puts("a #{b} c")
  end
')

  c = Compiler.new(e)
  c.rewrite_concat(prog)
  expect_eq(prog.inspect, [:do, [:if, [:<, :a, 2], [:do, [:callm, :STDERR, :puts, [[:callm, [:callm, [:callm, "a ", :to_s], :concat, [[:callm, :b, :to_s]]], :concat, [[:callm, " c", :to_s]]]]]]]].inspect, "concat => callm (2)")

  dummypos = Scanner::Position.new("test", 1,1)

  c = Compiler.new
  prog = mock_parse('
    each_byte do |c|
      h = h * 33 + c
    end
  ')
  p prog
  res = c.find_vars(prog, [[:h]], Set.new, Hash.new(0))
  expect_eq(res.inspect, "[[], #<Set: {:h}>]", "find_vars should identify all variables in a proc")

  c = Compiler.new
  prog = mock_parse('
    with_register_for do
      @e.save_result(scope,right)
    end
  ')
  p prog
  res = c.find_vars(prog, [[:scope, :left, :right]], Set.new, Hash.new(0))
  expect_eq(res.inspect, "[[:left], #<Set: {:scope, :right}>]", "find_vars_should identify all variables in a proc")

  c = Compiler.new
  prog = mock_parse('
    with_register_for do
      @e.save_result(foo(scope,right))
    end
  ')

  res = c.find_vars(prog[1][3][2][0][3], [[:scope, :left, :right]], Set.new, Hash.new(0), true)
  expect_eq(res.inspect, "[[:left], #<Set: {:scope, :right}>]", "find_vars_should identify all variables in a proc")

  p prog[1][3][2]
  res = c.find_vars(prog[1][3][2], [[:scope, :left, :right]], Set.new, Hash.new(0), true)
  expect_eq(res.inspect, "[[:left], #<Set: {:scope, :right}>]", "find_vars_should identify all variables in a proc [x]")

  c = Compiler.new(e)
  prog = [[:call, :p, [:arg, :arg2]]]
  res = c.find_vars(prog, [[:arg,:arg2], Set.new], Set.new, Hash.new(0), true)
  expect_eq(res.inspect, "[[], #<Set: {:arg, :arg2}>]", "find_vars should identify all variables in a proc")

  prog = E[E[dummypos,:proc, [], [[:call, :p, [:arg, :arg2]]]]]
  res = c.find_vars(prog, [[:arg,:arg2]], Set.new, Hash.new(0))
  expect_eq(res.inspect, "[[], #<Set: {:arg, :arg2}>]", "find_vars should identify all variables references in method body")

  c = Compiler.new(e)
  prog = E[:defm, :foo, E[:arg, :arg2], E[E[dummypos,:proc, [], [[:call, :p, [:arg, :arg2]]]]]]
  c.rewrite_let_env(prog)

  prog2 = E[:defm, :foo, E[:arg, :arg2], E[E[dummypos,:proc, [], [:arg, [:call, :p, [:arg, :arg2]]]]]]
  c.rewrite_let_env(prog2)

  p1=(prog.flatten - [:arg])
  p2=(prog2.flatten - [:arg])
  expect_eq(p1.inspect, p2.inspect, "def foo(arg,arg2); proc do p(arg,arg2); end vs. def foo(arg,arg2); proc do arg; p(arg,arg2); end")

  c = Compiler.new(e)
  prog = mock_parse('
  def foo
    yield
  end
')
  c.preprocess(prog)
  expect_eq(prog[1][3].inspect, "[:let, [:__env__, :__tmp_proc], [:sexp, [:assign, :__env__, [:call, :__alloc_mem, [8]]]], [:assign, [:index, :__env__, 1], :__closure__], [:callm, [:index, :__env__, 1], :call, nil]]",
    "yield triggers a rewrite even with no arguments")

end


def test_string
  expect_eq("foo".gsub("o","x"), "fxx", "String#gsub - Simple character substitution")
  expect_eq("foo".gsub("o","xy"), "fxyxy", "String#gsub - Replace character with string")
  expect_eq("foo\nbar".gsub("\n","\\n"), "foo\\nbar", "String#gsub - Replace character with string with escape characters")

  expect_eq("e" <=> "d", 1, "String#<=> should return 1 if left string sorts after right string")
  expect_eq("foo" <=> "f", 1, "String#<=> should return 1 for 'foo' <=> 'f'")
end

test_fixnum
test_symbol
test_array
test_set
test_hash
test_mockio
test_scannerstring
test_scanner_basics
test_parserbase_basics
test_sym
test_atom
test_respond_to
test_sexp_basics
test_tokenizer
test_methodname_tokenizer
test_shunting
test_parser
test_destructuring
test_depth_first
test_string
test_compiler


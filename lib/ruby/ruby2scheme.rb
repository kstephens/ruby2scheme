gem 'ParseTree'
require 'parse_tree'

require 'pp'

module Ruby2Scheme
  class Translator
    attr_accessor :output, :module_path

    def initialize
      @module_path = [ ]
    end

    def parse expr 
      expr = ::ParseTree.translate(expr) if String === expr
      return expr unless Array === expr
      expr
    end
    
    def compile! expr
      puts "ruby =\n#{expr}\n----"
      expr = parse(expr) if String === expr
      puts "sexpr = #{PP.pp(expr, '')}"
      @output = ''
      x! expr
      puts "lisp =\n#{output}\n----"
    end
    
    def x! expr
      expr_save = @expr
      @expr = expr
      # $stderr.puts "x: expr = #{expr.inspect}"
      case @expr
      when :nil
        x_nil
      when Array
        send(:"x_#{expr[0]}", *@expr)
      end
    ensure
      @expr = expr_save
    end

    def x_class! expr
      expr_save = @expr
      @expr = expr
      # $stderr.puts "x: expr = #{expr.inspect}"
      case @expr
      when :nil
        x_nil
      when Array
        send(:"x_class_#{expr[0]}", *@expr)
      end
    ensure
      @expr = expr_save
    end

    def x_class head, name, thing, scope
      save_module_path = @module_path
      @module_path = @module_path.dup << name

      e! "(r2s:class '"
      e! name
      e! "\n"
      x_class! scope
      e! ")"
    ensure
      @module_path = save_module_path
    end

    def x_class_scope head, *exprs
      exprs.each do | x |
        x_class! x
        e! "\n"
      end
    end

    def x_class_block head, *exprs
      # $stderr.puts "  x_class_block exprs = #{exprs.inspect}"
      exprs.each do | x |
        x! x
        e! "\n"
      end
    end

    def x_defn head, name, scope
      e! "  (r2s:def '"
      e! name
      e! " "
      x_defn_scope scope
      e! ")\n"
    end

    def x_defn_scope scope
      scope, block = *scope
      #$stderr.puts "  scope = #{scope.inspect}"
      #$stderr.puts "  block = #{block.inspect}"
      x! block
    end

    def x_block head, args, *body
      save_block_arg = @block_arg
      @block_arg = :'r2s::blk'
      body.each do | x |
        if Array === x && x[0] == :block_arg
          @block_arg = x[1]
        end
      end

      e! "(lambda "
      x! args
      e! " "
      body.each do | x |
        x! x
      end
      e! ")"
    ensure
      @block_arg = save_block_arg
    end

    def x_block_arg head, name
      # @block_arg = name
    end

    def x_args head, *args
      e! "(", :self, " ", @block_arg
      args.each do | x |
        e! " "
        if (x = x.to_s.dup).sub!(/^\*/, '')
          e! " . "
        end
        e! x
      end
      e! ")"
    end

    def x_fcall head, meth, args
      s = :"x_fcall_#{meth}"
      s = send(s, head, meth, args) if respond_to?(s)
      return if s
      e! "(r2s:send '"
      e! meth
      e! " "
      e! "self"
      e! " "
      e! nil # blk
      array_each(args) do | x |
        e! " "
        x! x
      end
      e! ")"
    end

    def x_yield head, args = nil
      e! "("
      e! @block_arg
      array_each(args) do | x |
        e! " "
        x! x
      end
      e! ")"
    end

    def x_fcall_attr_accessor head, meth, args
      e! "  (r2s:attr_accessor "
      array_each(args) do | x |
        e! " "
        x! x
      end
      e! ")"
      self
    end

    def x_call head, rcvr, meth, args
      e! "(r2s:send '"
      e! meth
      e! " "
      x! rcvr
      e! " "
      x! nil # blk
      array_each(args) do | x |
        e! " "
        x! x
      end
      e! ")"
    end

    def x_array head, *exprs
      exprs.each do | x |
        e! " "
        x! x
      end
    end

    def x_vcall head, sym
      e! sym
    end

    def x_lvar head, sym
      e! sym
    end

    def x_ivar head, sym
      e! "(r2s:ivar self '"
      e! sym
      e! ")"
    end

    def x_iasgn head, name, value
      e! "(set! "
      x_ivar head, name
      e! " "
      x! value
      e! ")"
    end

    def x_cvar head, sym
      e! "(r2s:cvar '#{module_path * '::'} '"
      e! sym
      e! ")"
    end

    def x_cvasgn head, name, value
      e! "(set! "
      x_cvar head, name
      e! " "
      x! value
      e! ")"
    end

    def x_cvdecl head, name, value
      e! "  (set! "
      x_cvar :cvar, name
      e! " "
      x! value
      e! ")"
    end

    def x_lit head, val
      case val
      when Symbol
        e! "'#{val}"
      else
        e! val.inspect
      end
    end

    def compile_nil
      e! 'nil'
    end

    def e! *args
      args.each do | x |
        _e! x
      end
      self
    end

    def _e! x
      @output << x.to_s
      $stderr.puts "  output = #{@output}" if @emit_debug
      self
    end

    def array_each a, &blk
      return if a == nil
      raise TypeError unless Array === a
      raise ArgumentError unless :array === a.first
      a = a.dup
      a.shift
      a.each(&blk)
    end
  end
end

r2s = Ruby2Scheme::Translator.new
r2s.compile! "puts x + 5"

#r2s.compile! "lambda { | x | x + 5 }"
r2s.compile! <<"END"
class Foo
  attr_accessor :a, :b
  @@cv = 123
  def bar x, y, *args
    x + y + @z + @@cv
  end
  def foo x
    @z = x
    @@cv = @z + 1
  end
  def takes_block
    yield
  end
  def takes_named_block &blk
    yield 1, 2
  end
end
END


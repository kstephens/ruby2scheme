gem 'ParseTree'
require 'parse_tree'

require 'pp'

module Ruby2Scheme
  class Translator
    attr_accessor :output, :module

    def initialize
      @module = [ ]
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
      save_module = @module
      @module = @module.dup << name

      emit! "(r2s:class '"
      emit! name
      emit! "\n"
      x_class! scope
      emit! ")"
    ensure
      @module = save_module
    end

    def x_class_scope head, *exprs
      exprs.each do | x |
        x_class! x
        emit! "\n"
      end
    end

    def x_class_block head, *exprs
      # $stderr.puts "  x_class_block exprs = #{exprs.inspect}"
      exprs.each do | x |
        x! x
        emit! "\n"
      end
    end

    def x_defn head, name, scope
      emit! "  (r2s:def '"
      emit! name
      emit! " "
      x_defn_scope scope
      emit! ")\n"
    end

    def x_defn_scope scope
      scope, block = *scope
      #$stderr.puts "  scope = #{scope.inspect}"
      #$stderr.puts "  block = #{block.inspect}"
      x! block
    end

    def x_block head, args, *body
      emit! "(lambda "
      x! args
      emit! " "
      body.each do | x |
        x! x
      end
      emit! ")"
    end

    def x_args head, *args
      emit! "("
      args.each do | x |
        emit! " "
        emit! x
      end
      emit! ")"
    end

    def x_fcall head, meth, args
      s = :"x_fcall_#{meth}"
      s = send(s, head, meth, args) if respond_to?(s)
      return if s
      emit! "(r2s:send '"
      emit! meth
      emit! " "
      emit! "self"
      array_each(args) do | x |
        emit! " "
        x! x
      end
      emit! ")"
    end

    def x_fcall_attr_accessor head, meth, args
      emit! "  (r2s:attr_accessor "
      array_each(args) do | x |
        emit! " "
        x! x
      end
      emit! ")"
      self
    end

    def x_call head, rcvr, meth, args
      emit! "(r2s:send '"
      emit! meth
      emit! " "
      x! rcvr
      array_each(args) do | x |
        emit! " "
        x! x
      end
      emit! ")"
    end

    def x_array head, *exprs
      exprs.each do | x |
        emit! " "
        x! x
      end
    end

    def x_vcall head, sym
      emit! sym
    end

    def x_lvar head, sym
      emit! sym
    end

    def x_ivar head, sym
      emit! "(r2s:ivar self '"
      emit! sym
      emit! ")"
    end

    def x_lit head, val
      case val
      when Symbol
        emit! "'#{val}"
      else
        emit! val.inspect
      end
    end


    def compile_nil
      emit! 'nil'
    end

    def emit! x
      @output << x.to_s
      $stderr.puts "  output = #{@output}" if @emit_debug
      self
    end

    def array_each a, &blk
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
  def bar x, y, *args
    x + y + @z
  end
end
END



class Generator
    OPCODES = %w(ldc ld st add sub mul div ceq cgt cgte atom cons car cdr sel join) +
              %w(ldf ap rtn dum rap stop tsel tap trap dbug brk)

    class Emitter
        def ldc(n)    puts "LDC #{n}"       end # load constant
        def ld(n,i)   puts "LD #{n} #{i}"   end # load from environment
        def st(n,i)   puts "ST #{n} #{i}"   end # store to environment
        def add()     puts "ADD"            end # integer addition
        def sub()     puts "SUB"            end # integer subtraction
        def mul()     puts "MUL"            end # integer multiplication
        def div()     puts "DIV"            end # integer division
        def ceq()     puts "CEQ"            end # compare equal
        def cgt()     puts "CGT"            end # compare greater than
        def cgte()    puts "CGTE"           end # compare greater than or equal
        def atom()    puts "ATOM"           end # test if value is an integer
        def cons()    puts "CONS"           end # allocate a CONS cell
        def car()     puts "CAR"            end # extract first element from CONS cell
        def cdr()     puts "CDR"            end # extract second element from CONS cell
        def sel(x,y)  puts "SEL #{x} #{y}"  end # conditional branch
        def join()    puts "JOIN"           end # return from branch
        def ldf(x)    puts "LDF #{x}"       end # load function
        def ap(x)     puts "AP #{x}"        end # call function
        def rtn()     puts "RTN"            end # return from function call
        def dum(x)    puts "DUM #{x}"       end # create empty environment frame
        def rap(x)    puts "RAP #{x}"       end # recursive environment call function
        def stop()    puts "STOP"           end # terminate co-processor execution, see RTN
        def tsel(x,y) puts "TSEL #{x} #{y}" end # tail-call conditional branch
        def tap(x)    puts "TAP #{x}"       end # tail-call function
        def trap(x)   puts "TRAP #{x}"      end # recursive environment tail-call function
        def dbug()    puts "DBUG"           end # printf debugging
        def brk()     puts "BRK"            end # breakpoint debugging

        def listing(v) puts "; #{v}" end


        def emit(list)
            list.each {|op| emit_op(op) }
        end

        def emit_op(op)
            m = method(op.code)
            case m.arity
            when 0 then send(op.code)
            when 1 then send(op.code, op.x)
            when 2 then send(op.code, op.x, op.y)
            end
        end

    end

    class Opcode
        attr_reader :code
        attr_accessor :x, :y

        def initialize(code, x=nil, y=nil)
            @code = code
            @x = x
            @y = y
        end

        def inspect
            s = "op:#{code}"
            s << " x:#{x}" if x
            s << " y:#{y}" if y
            s
        end
    end

    class ListingOp < Opcode
        def initialize(s)
            super(:listing, s)
        end
    end

    class Iron

        def initialize(debug)
            @debug = debug
            @list = []
            @ip = 0
            @ctable = {}
            @alias = {}
        end

        def flatten(symtable, entryp)
            m = symtable.delete(entryp)
            append_to_list(m)

            symtable.each_value do |s|
                append_to_list(s)
            end

            fixup(@list, @ctable)
        end

        def append_to_list(sym)
            return if @ctable[sym.name]

            if sym.type == '\''
                @alias[sym.name] = sym.value
                return
            end

            @list << ListingOp.new("#{@ip}: #{sym.name}") if @debug
            @ctable[sym.name] = @ip
            @list += sym.code
            @ip += sym.code.size
        end

        def fixup(list, ctable)
            list.map do |c|
                if c.is_a?(String)
                    [resolve(c, ctable)]
                elsif c.is_a?(Array)
                    fixup(c, ctable)
                elsif c.is_a?(ListingOp)
                    [c]
                else
                    c.x = resolve(c.x, ctable) unless c.x.nil?
                    c.y = resolve(c.y, ctable) unless c.y.nil?
                    [c]
                end
            end
            .flatten(1)
        end

        INTERNAL = Hash[OPCODES.zip([true] * OPCODES.size)]

        def resolve(v, ctable)
            return v if v.is_a?(Integer)
            n = v.is_a?(String) ? v : v.name

            if a = @alias[n]
                n = a
            end

            return n if INTERNAL[n]
            ctable[n] or raise Exception, "! could not resolve #{v} in #{ctable}"
        end
    end

    class Lister

        def initialize(debug=false)
            @debug = debug
            @sym = {}
            @unprocessed = []
            @seen = {}
        end

        def list(symtable, entryp)
            @current_frame = nil
            symtable.each_value {|v| process(v, false) }

            while @unprocessed.size > 0
                process( @unprocessed.delete_at(0) , false)
            end

            iron = Iron.new(@debug)
            iron.flatten(@sym, entryp)
        end

        def process(sym, ignoredefs=true)
            if sym.is_a?(Fixnum)
                return [] << Opcode.new(:ldc, sym)
            elsif sym.is_a?(Array)
                return sym.map {|n| process(n) }.flatten(1)
            end

            r = case sym.type
            when 'f' then begin x = _fundef(sym); ignoredefs ? [] : x end
            when 'l' then _lambda(sym)
            when '[' then _block(sym)
            when 'c' then _fcall(sym)
            when 'v' then _localvar(sym)
            when 'a' then _arg(sym)
            when '\'' then _alias(sym)
            end

            append_from_symtable(sym.scope)
            r
        end

        def append_from_symtable(scope)
            return if @seen[scope.name]
            @seen[scope.name] = true
            scope.table.each_value do |s|
                unless s.reference?
                    @unprocessed << s unless @sym[s.name]
                end
            end
            scope.children.each {|n| append_from_symtable(n) }
        end


        def frame_border(sym)
            if sym.dataframe && sym.dataframe.parent == @current_frame
                _frame(sym) || []
            else
                @current_frame = sym.dataframe
                []
            end
        end

        def _frame(sym)
            @current_frame = sym.dataframe
            if sym.dataframe.size > 0
                [] << Opcode.new(:dum, sym.dataframe.size)
            end
        end


        def _alias(sym)
            @sym[sym.name] = sym
        end

        def _fundef(sym)
            @sym[sym.name] = sym
            sym.code = frame_border(sym) + process(sym.value) << Opcode.new(:rtn)
        end

        def _lambda(sym)
            @sym[sym.name] = sym
            sym.code = process(sym.value) << Opcode.new(:rtn)
            frame_border(sym) <<
                Opcode.new(:ldf, sym.name)
        end

        def _block(sym)
            sym.code = frame_border(sym) + process(sym.value)
        end

        def _fcall(sym)
            sym.code = frame_border(sym) + (_intfcall(sym) || _libfcall(sym))
        end

        INTERNAL = %w(add sub mul div ceq cgt cgte atom car cdr cons sel tsel dbug brk)
        def _intfcall(sym)
            return unless INTERNAL.include?(sym.name)
            sym.code = sym.value.map {|n| process(n) }.flatten(1) << Opcode.new(sym.name.to_sym)
        end

        def _libfcall(sym)
            args = sym.value.map {|n| process(n) }.flatten(1)
            il = []
            il += args
            il << Opcode.new(:ldf, sym.name)
            il << Opcode.new(:ap, sym.arity)
        end

        def _localvar(sym)
            n, i = resolve_localvar(sym.name, sym.scope, sym.dataframe)
            [] << Opcode.new(:ld, n, i)
        end

        def resolve_localvar(name, scope, dataframe=nil, n=0)
            raise Exception, "! could not resolve #{name}" if scope.nil?

            if !dataframe.nil? && scope.dataframe != dataframe
                n += 1 if dataframe.size > 0
                dataframe = scope.dataframe
            end

            if sym = scope.table[name] and sym.type != 'v'
                return n, scope.table.keys.index(name)
            end

            resolve_localvar(name, scope.parent, dataframe, n)
        end

        def _arg(sym)
            unless sym.value.nil?
                sym.code = frame_border(sym) + process(sym.value)
            end
        end
    end


    def generate(symtable, entryp, debug=false)
        lister = Lister.new(debug)
        l = lister.list(symtable, entryp)

        Emitter.new.emit(l)
    end

end

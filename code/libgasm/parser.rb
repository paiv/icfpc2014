require 'treetop'

module Gasm
    class GasmProgram < Treetop::Runtime::SyntaxNode
        def expressions
            return self.elements.delete_if {|n| !n.respond_to?(:expression)} .map {|n| n.expression.value}
        end
    end

    class Label < Treetop::Runtime::SyntaxNode
        def value
            return self.identifier.value
        end
    end

    class Instruction < Treetop::Runtime::SyntaxNode
        def value
            r = [identifier.value]
            r << a.arg.value if a.respond_to?(:arg)
            r << b.arg.value if b.respond_to?(:arg)
            r
        end
    end

    class IntegerLiteral < Treetop::Runtime::SyntaxNode
        def value
            text_value.to_i
        end
    end

    class Identifier < Treetop::Runtime::SyntaxNode
        def value
            text_value
        end
    end
end

class Parser
    Treetop.load(File.join(File.dirname(__FILE__), 'gasm.treetop'))
    @@parser = GasmParser.new

    def parse(v)
        tree = @@parser.parse(v)
        if tree.nil?
            raise Exception, "(#{@@parser.failure_line}:#{@@parser.failure_column}) #{@@parser.failure_reason}"
        end
        return tree.expressions
    end
end

class Assembler

    class Instruction
        attr_accessor :value

        def initialize(v)
            @value = v
        end

        def resolved?
            @value[1..10].all? {|x| x.is_a?(Integer) }
        end

        def to_s
            @value.join(' ')
        end
    end

    def initialize
        @queue = []   # [Instruction]
        @labels = {}  # label => instruction pointer
        @pending = {} # label => [Instruction]
        @ip = 0
    end

    def process(prog)
        prog.each {|n| filter(n)}
    end

    def filter(line)
        if line.is_a?(String)
            @labels[line] = @ip
            resolve_for(line)
        elsif line.is_a?(Array)
            @queue << add_instruction(line)
            @ip += 1
        else
            raise Exception, "! unhandled data type of " + line
        end
        flush
    end

    def add_instruction(line)
        line = resolve(line)
        r = Instruction.new(line)
        line[1..10].each do |x|
            add_pending(x, r) if x.is_a?(String)
        end
        r
    end

    def add_pending(label, instruction)
        @pending[label] = [] if @pending[label].nil?
        @pending[label] << instruction
    end

    def resolve_for(label)
        list = @pending.delete(label)
        list.each do |e|
            e.value = resolve(e.value)
        end unless list.nil?
    end

    def resolve(v)
        v[1..10] = v[1..10].collect do |n|
            n.is_a?(String) ? (@labels[n] || n) : n
        end
        v
    end

    def flush
        @queue = @queue.drop_while do |x|
            puts x.to_s if x.resolved?
            x.resolved?
        end
    end
end


if $0 == __FILE__

    parser = Parser.new
    ast = parser.parse(ARGF.read)

    asm = Assembler.new
    asm.process(ast)

end

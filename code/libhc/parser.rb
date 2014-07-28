require 'treetop'

module Hi
    class HiProgram < Treetop::Runtime::SyntaxNode
        def value
            elements.delete_if {|n| !n.respond_to?(:expression) } .map {|n| n.expression.value}
        end
    end

    class Expression < Treetop::Runtime::SyntaxNode
        def value
            body.value
        end
    end

    class Body < Treetop::Runtime::SyntaxNode
        def value
            elements.delete_if {|n| !n.respond_to?(:value) } .map {|n| n.value}
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

    class Operator < Treetop::Runtime::SyntaxNode
        def value
            text_value
        end
    end

    class QuotedIdentifier < Treetop::Runtime::SyntaxNode
        def value
            text_value
        end
    end

    class QuotedOperator < Treetop::Runtime::SyntaxNode
        def value
            text_value
        end
    end

end

class Parser
    Treetop.load(File.join(File.dirname(__FILE__), 'hi.treetop'))
    @@parser = HiParser.new

    def parse(v)
        tree = @@parser.parse(v)
        if tree.nil?
            raise Exception, "(#{@@parser.failure_line}:#{@@parser.failure_column}) #{@@parser.failure_reason}"
        end
        return tree.value
    end
end

if $0 == __FILE__

    parser = Parser.new
    p ast = parser.parse(ARGF.read)

end

require_relative 'parser'
require_relative 'generator'
require_relative 'core'
require_relative 'corelib'

class Compiler

    INTERNAL_FUNCS = %w(ldc ld st add sub mul div ceq cgt cgte atom cons car cdr sel join) +
                     %w(ldf ap rtn dum rap stop tsel tap trap dbug brk)

    class Optimizer

        def initialize(scope)
            @scope = scope
        end

        def optimize(entryp)
            used = all_used(@scope.table[entryp])

# puts ':all used symbols'
# p used
# puts '--'

# @scope.table.each_value {|n| puts n.inspect_recursive }

            # ~~
            # remove_unused(@scope, used)
            @scope.table
        end

        def all_used(sym, used={}, parent_scope=nil)
            if sym.is_a?(Sym)
                unless used[sym.name]
                    used[sym.name] = true
                    all_used(sym.value, used, sym.scope)
                    all_used(resolve_refs(sym.name, sym.scope), used)
                end
            elsif sym.is_a?(String)
                unless used[sym]
                    used[sym] = true
                    if x = resolve_refs(sym, parent_scope) #find_symbol(sym, @scope)
                        all_used(x, used, x.scope)
                    end
                end
            elsif sym.is_a?(Array)
                sym.each {|n| all_used(n, used, parent_scope) }
            end
            used
        end

        def resolve_refs(name, scope)
            if scope.nil?
                return name if INTERNAL_FUNCS.include?(name)
                raise Exception, "! could not resolve #{name}"
            end
            # return if scope.nil?
            if sym = scope.table[name] and !sym.reference?
                return sym
            end
            resolve_refs(name, scope.parent)
        end

        def find_symbol(name, scope)
            return if scope.nil?
            if sym = scope.table[name]
                return sym
            end
            scope.children.find {|s| s.table[name] }
        end

        def remove_unused(scope, used)
# puts ':before'
# p scope.table.keys
            scope.table.delete_if {|k,v| not used[k]}
# puts ':after'
# p scope.table.keys
            scope.children.each {|s| remove_unused(s, used) }
            scope.table
        end
    end


    def initialize
        @global = Scope.global
        @alias = {}
    end

    def compile(ast, entryp, debug=false)
        ast.each {|node| process(node, @global) }
        table = Optimizer.new(@global).optimize(@global.name + entryp)
        Generator.new.generate(table, @global.name + entryp, debug)
    end

    def process(ast, scope)
        if ast.is_a?(Array)
            process_def(ast, scope)
        else
            process_term(ast, scope)
        end
    end

    def process_def(ast, scope)
        name = ast[0].to_sym
        if a = @alias[name]
            name = a
        end

        if self.class.method_defined?(name)
            m = method(name)
            m.call(ast, scope)
        else
            process_fcall(ast, scope)
        end
    end

    def process_fcall(ast, scope)
        sym = Sym.new(resolve(ast[0], scope), 'c', scope)
        sym.arity = ast.size - 1
        fscope = Scope.new(scope)
        sym.value = ast[1..ast.size].map {|n| process(n, fscope) }.flatten(1)
        sym
    end

    def process_term(ast, scope)
        if ast.is_a?(String)
            scope.add(resolve(ast, scope), 'v')
        elsif ast.is_a?(Integer)
            ast
        else
            raise Exception, "! unexpected term: #{ast}"
        end
    end

    def resolve(name, scope)
        if a = @alias[name]
            name = a
        end

        if scope.nil?
            return name if INTERNAL_FUNCS.include?(name)
            raise Exception, "! could not resolve #{name}"
        end
        s = scope.name + name
        if sym = scope.table[s]
            return sym.value if sym.alias?
            return sym.is_a?(Sym) ? sym.name : sym
        end
        return resolve(name, scope.parent)
    end

end


if $0 == __FILE__

    parser = Parser.new
    ast = parser.parse(ARGF.read)

    cc = Compiler.new
    cc.compile(ast, 'main', true)

end

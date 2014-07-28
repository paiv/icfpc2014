require_relative 'core'

class Compiler

    Sym = HiCore::Sym
    Scope = HiCore::Scope
    DataFrame = HiCore::DataFrame
    RandomString = HiCore::RandomString

    def alias(ast, scope)
        raise Exception, "! expected quoted identifier: #{ast[1]}" unless ast[1] =~ /^'(.*)/
        n = $1
        raise Exception, "! expected quoted identifier: #{ast[2]}" unless ast[2] =~ /^'(.*)/
        m = $1

        @alias[n] = m
        # sym = scope.add(scope.name + n, '\'')
        # sym.value = resolve(m, scope)
    end

    def defun(ast, scope)
        sym = scope.add(scope.name + ast[1], 'f')
        sym.arity = ast[2].size

        fscope = Scope.new(scope)
        ast[2].each do |n|
            raise Exception, '! expected named argument: ' + n.to_s unless n.is_a?(String)
            fscope.add(fscope.name + n, 'a')
        end

        sym.value = ast[3..ast.size].map {|n| process(n, fscope) }.flatten(1)
# puts sym.scope.inspect_recursive
        sym
    end

    def lambda(ast, scope)
        sym = scope.add(scope.name + RandomString.sym('lambda'), 'l')
        sym.arity = ast[1].size

        fscope = Scope.new(scope)
        ast[1].each do |n|
            raise Exception, '! expected named argument: ' + n.to_s unless n.is_a?(String)
            fscope.add(fscope.name + n, 'a')
        end

        sym.value = ast[2..ast.size].map {|n| process(n, fscope) }.flatten(1)
        sym
    end

    def let(ast, scope)

        # fun def
        sym = scope.add(scope.name + RandomString.sym('let'), 'f')
        sym.arity = ast[1].size

        fscope = Scope.new(scope)
        ast[1].each do |arg|
            n = arg[0]
            raise Exception, '! expected named argument: ' + n.to_s unless n.is_a?(String)
            fscope.add(fscope.name + n, 'a')
        end

        sym.value = ast[2..ast.size].map {|n| process(n, fscope) }.flatten(1)

        # fun call
        fcall = Sym.new(sym.name, 'c', scope)
        fcall.arity = sym.arity

        fscope = Scope.new(scope)
        fcall.value = ast[1].map {|n| process(n[1], fscope) } .flatten(1)
        fcall
    end

end

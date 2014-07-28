
module HiCore

# symbol types:
# f - function
# l - lambda
# a - argument
# c - function call
# v - load local var

class Sym
    attr_reader :name, :type, :scope
    attr_accessor :value, :code, :arity

    def initialize(name, type, scope)
        @name = name
        @type = type
        @scope = scope
        @arity = 0
    end

    def copy
        Sym.new(name, type, scope)
    end

    def dataframe
        scope.dataframe
    end

    def reference?
        %w(v c).include?(type)
    end
    def alias?
        type == '\''
    end

    def to_s
        name
    end
    def inspect
        s = "sym.#{type}:#{name}"
        s += ".#{arity}" if arity > 0
        s
    end

    def inspect_recursive(l=1)
        ws = '  ' * l
        "<#{inspect}\n" +
            ws + "value: " + value.inspect + "\n" +
            # ws + "scope: " + scope.inspect_recursive + "\n" +
            '  ' * (l - 1) + ">"
    end
end

class Scope
    attr_reader :name, :level, :table, :parent, :children, :dataframe

    def initialize(parent, dataframe=nil, name=nil)
        @children = []
        @name = name || RandomString.sym('scope') + '_'
        @level = parent.nil? ? 0 : parent.level + 1
        @parent = parent
        parent.add_child(self) unless parent.nil?
        @table = {}
        @dataframe = dataframe
    end

    def self.global()
        self.new(nil, DataFrame.new(0), '__scope_global_')
    end

    def frame(size)
        Scope.frame(size, self)
    end
    def self.frame(size, parent)
        Scope.new(parent, DataFrame.new(size, parent.dataframe))
    end

    def add_child(scope)
        raise Exception, "! could not add ancestor to children" if ancestor?(scope)
        @children << scope
    end

    def ancestor?(scope)
        scope == parent || parent.ancestor?(scope) unless parent.nil?
    end

    def add(name, type)
        sym = Sym.new(name, type, self)
        @table[sym.name] = sym
    end

    def dataframe
        @dataframe || parent.dataframe
    end

    def to_s
        name
    end
    def inspect
        "#{name} (#{table.size}) parent:#{parent.nil? ? 'nil' : parent.name}"
    end
    def inspect_recursive(l=1)
        ws = '  ' * l
        "<#{inspect}\n" +
            ws + "symbols: " + table.values.map{|x| x.inspect}.join(', ') + "\n" +
            ws + "children:\n" +
            ws + children.map{|c| c.inspect_recursive(l+1) }.flatten(1).join("\n" + ws) + "\n" +
            '  ' * (l - 1) + ">"
    end
end

class DataFrame
    attr_reader :name, :size, :parent

    def initialize(size, parent=nil)
        @size = size
        @name = RandomString.sym('frame') + '_'
        @parent = parent
    end

    def to_s
        name
    end
    def inspect
        "#{name} parent:#{parent.nil? ? nil : parent.name}"
    end
end

class RandomString
    def self.sym(name)
        self.rn(name)
    end

    ABCD = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten

    def self.rn(name)
        js = (0...12).map { ABCD[rand(ABCD.length)] }.join
        "__#{name}_" + js
    end
end

end

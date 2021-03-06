module Erector
  module Externals
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      # Express a dependency of this widget
      # Multiple forms:
      #   depends_on(type, text, options = {})
      # for example
      #   depends_on(:js, '/foo.js', :embed=>true)
      #
      # Other variants:
      #   depends_on(type, an_io, ... # file to be read
      #   depends_on('blah.js' ... infer :js
      #   depends_on('blah.css' ... infer :css
      #   depends on :js, 'file1.js', 'file2.js'... [options]
      #   depends_on :js => ["foo.js", "bar.js"], :css=>['file.css']
      #   depends_on :js => ["foo.js", "bar.js"], other_option=>:blah
      def depends_on(*args)
        x = interpret_args(*args)
        push_dependency(x)
      end

      # deprecated in favor of #depends_on
      def external(type, value, options = {})
        @_dependencies ||= []
        type = type.to_sym
        x = Dependency.new(type, value, options)
        @_dependencies << x unless @_dependencies.include?(x)
      end

      # returns all dependencies of the given type from this class and all its
      # superclasses
      def dependencies(type)
        type = type.to_sym
        deps = []
        deps += superclass.dependencies(type) if superclass.respond_to?(:dependencies)
        deps += @_dependencies.select { |x| x.type == type } if @_dependencies
        deps.uniq
      end

      private
      INFERABLE_TYPES = [:css, :js]

      def interpret_args(*args)
        options =  {}
        options = args.pop if args.last.is_a?(::Hash)
        if args.empty? && options.any?
          deps = []
          texts_hash = {}
          INFERABLE_TYPES.each do |t|
            texts_hash[t] = options.delete(t) if options.has_key? t
          end
          texts_hash.each do |t, texts|
            texts.each do |text|
              deps << interpret_args(t, text, options)
            end
          end
          return deps
        elsif args[0].class == Symbol
          type = args.shift
        else
          type = /.+\.js/.match(args[0]) ? :js : :css
        end

        deps = args.map do |text|
          Dependency.new(type, text, options)
        end
        deps.size == 1 ? deps.first : deps
      end

      def push_dependency(*dependencies)
        @_dependencies ||= []
        [*dependencies].flatten.each do |dep|
          if dep.is_a? Erector::Dependency
            @_dependencies << dep unless @_dependencies.include?(dep)
          else
            raise "expected Dependency, got #{x.class}: #{x.inspect}"
          end
        end
      end
    end

    def render_with_externals(options_to_external_renderer = {})
      output = Erector::Output.new
      self.to_a(:output => output)
      nested_widgets = output.widgets.to_a
      externals = ExternalRenderer.new({:classes => nested_widgets}.merge(options_to_external_renderer)).to_s(:output => output)
      output.to_a
    end

    def render_externals(options_to_external_renderer = {})
      output_for_externals = Erector::Output.new
      nested_widgets = output.widgets
      externalizer = ExternalRenderer.new({:classes => nested_widgets}.merge(options_to_external_renderer))
      externalizer._render(:output => output_for_externals)
      output_for_externals.to_a
    end
  end
end

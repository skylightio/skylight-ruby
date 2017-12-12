module Skylight
  # Instrumenting a specific method will cause an event to be created every time that method is called.
  # The event will be inserted at the appropriate place in the Skylight trace.
  #
  # To instrument a method, the first thing to do is include {Skylight::Helpers Skylight::Helpers}
  # into the class that you will be instrumenting. Then, annotate each method that
  # you wish to instrument with {Skylight::Helpers::ClassMethods#instrument_method instrument_method}.
  module Helpers

    # @see Skylight::Helpers
    module ClassMethods
      # @api private
      def method_added(name)
        super

        if opts = @__sk_instrument_next_method
          @__sk_instrument_next_method = nil
          instrument_method(name, opts)
        end
      end

      # @api private
      def singleton_method_added(name)
        super

        if opts = @__sk_instrument_next_method
          @__sk_instrument_next_method = nil
          instrument_class_method(name, opts)
        end
      end

      # @overload instrument_method
      #   Instruments the following method
      #
      #   @example
      #     class MyClass
      #       include Skylight::Helpers
      #
      #       instrument_method
      #       def my_method
      #         do_expensive_stuff
      #       end
      #
      #     end
      #
      # @overload instrument_method([name], opts={})
      #   @param [Symbol|String] [name]
      #   @param [Hash] opts
      #   @option opts [String] :category ('app.method')
      #   @option opts [String] :title (ClassName#method_name)
      #   @option opts [String] :description
      #
      #   You may also declare the methods to instrument at any time by passing the name
      #   of the method as the first argument to `instrument_method`.
      #
      #   @example With name
      #     class MyClass
      #       include Skylight::Helpers
      #
      #       def my_method
      #         do_expensive_stuff
      #       end
      #
      #       instrument_method :my_method
      #
      #     end
      #
      #   By default, the event will be titled using the name of the class and the
      #   method. For example, in our previous example, the event name will be:
      #   +MyClass#my_method+. You can customize this by passing using the *:title* option.
      #
      #   @example Without name
      #     class MyClass
      #       include Skylight::Helpers
      #
      #       instrument_method title: 'Expensive work'
      #       def my_method
      #         do_expensive_stuff
      #       end
      #     end
      def instrument_method(*args)
        opts = args.pop if Hash === args.last

        if name = args.pop
          title = "#{to_s}##{name}"
          __sk_instrument_method_on(self, name, title, opts || {})
        else
          @__sk_instrument_next_method = opts || {}
        end
      end

      # @overload instrument_class_method([name], opts={})
      #   @param [Symbol|String] [name]
      #   @param [Hash] opts
      #   @option opts [String] :category ('app.method')
      #   @option opts [String] :title (ClassName#method_name)
      #   @option opts [String] :description
      #
      #   You may also declare the methods to instrument at any time by passing the name
      #   of the method as the first argument to `instrument_method`.
      #
      #   @example With name
      #     class MyClass
      #       include Skylight::Helpers
      #
      #       def self.my_method
      #         do_expensive_stuff
      #       end
      #
      #       instrument_class_method :my_method
      #     end
      #
      #   By default, the event will be titled using the name of the class and the
      #   method. For example, in our previous example, the event name will be:
      #   +MyClass.my_method+. You can customize this by passing using the *:title* option.
      #
      #   @example With title
      #     class MyClass
      #       include Skylight::Helpers
      #
      #       def self.my_method
      #         do_expensive_stuff
      #       end
      #
      #       instrument_class_method :my_method, title: 'Expensive work'
      #     end
      def instrument_class_method(name, opts = {})
        title = "#{to_s}.#{name}"
        __sk_instrument_method_on(__sk_singleton_class, name, title, opts || {})
      end

    private

      def __sk_instrument_method_on(klass, name, title, opts)
        category = (opts[:category] || "app.method").to_s
        title    = (opts[:title] || title).to_s
        desc     = opts[:description].to_s if opts[:description]

        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          alias_method :"before_instrument_#{name}", :"#{name}"

          def #{name}(*args, &blk)
            span = Skylight.instrument(
              category:  :"#{category}",
              title:       #{title.inspect},
              description: #{desc.inspect})

            begin
              send(:before_instrument_#{name}, *args, &blk)
            ensure
              Skylight.done(span) if span
            end
          end
        RUBY
      end

      if respond_to?(:singleton_class)
        alias :__sk_singleton_class :singleton_class
      else
        def __sk_singleton_class
          class << self; self; end
        end
      end
    end

    # @api private
    def self.included(base)
      base.class_eval do
        @__sk_instrument_next_method = nil
        extend ClassMethods
      end
    end

  end
end

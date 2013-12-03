module Skylight
  module Helpers
    module ClassMethods
      def method_added(name)
        super

        if opts = @__sk_instrument_next_method
          @__sk_instrument_next_method = nil
          title = "#{to_s}##{name}"
          __sk_instrument_method_on(self, name, title, opts)
        end
      end

      def singleton_method_added(name)
        super

        if opts = @__sk_instrument_next_method
          @__sk_instrument_next_method = nil
          title = "#{to_s}.#{name}"
          __sk_instrument_method_on(__sk_singleton_class, name, title, opts)
        end
      end

      def instrument_method(*args)
        opts = args.pop if Hash === args.last

        if name = args.pop
          title = "#{to_s}##{name}"
          __sk_instrument_method_on(self, name, title, opts || {})
        else
          @__sk_instrument_next_method = opts || {}
        end
      end

    private

      def __sk_instrument_method_on(klass, name, title, opts)
        category = (opts[:category] || "app.method").to_s
        title    = (opts[:title] || title).to_s
        desc     = opts[:description].to_s if opts[:description]

        klass.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          alias_method :"#{name}_before_instrument", :"#{name}"

          def #{name}(*args, &blk)
            span = Skylight.instrument(
              category:  :"#{category}",
              title:       #{title.inspect},
              description: #{desc.inspect})

            begin
              #{name}_before_instrument(*args, &blk)
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

    def self.included(base)
      base.class_eval do
        @__sk_instrument_next_method = nil
        extend ClassMethods
      end
    end

  end
end

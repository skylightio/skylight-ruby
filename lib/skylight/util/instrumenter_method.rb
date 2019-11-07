module Skylight
  module Util
    module InstrumenterMethod
      def instrumenter_method(name, block: false)
        if block
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(*args)
              unless instrumenter
                return yield if block_given?
                return
              end

              instrumenter.#{name}(*args) { yield }
            end
          RUBY
        else
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(*args)
              instrumenter&.#{name}(*args)
            end
          RUBY
        end
      end
    end
  end
end

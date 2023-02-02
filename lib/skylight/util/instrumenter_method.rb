module Skylight
  module Util
    module InstrumenterMethod
      def instrumenter_method(name, wrapped_block: false)
        if wrapped_block
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(...)                      # def mute(...)
              unless instrumenter                 #   unless instrumenter
                return yield if block_given?      #     return yield if block_given?
                return                            #     return
              end                                 #   end
                                                  #
              instrumenter.#{name}(...)           #   instrumenter.mute(...)
            end                                   # end
          RUBY
        else
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(...)                      # def config(...)
              instrumenter&.#{name}(...)          #   instrumenter&.config(...)
            end                                   # end
          RUBY
        end
      end
    end
  end
end

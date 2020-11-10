module Skylight
  module Util
    module InstrumenterMethod
      def instrumenter_method(name, block: false)
        if block
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(*args)                      # def mute(*args)
              unless instrumenter                   #   unless instrumenter
                return yield if block_given?        #     return yield if block_given?
                return                              #     return
              end                                   #   end
                                                    #
              instrumenter.#{name}(*args) { yield } #   instrumenter.mute(*args) { yield }
            end                                     # end
          RUBY
        else
          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{name}(*args)              # def config(*args)
              instrumenter&.#{name}(*args)  #   instrumenter&.config(*args)
            end                             # end
          RUBY
        end
      end
    end
  end
end

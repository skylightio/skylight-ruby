module Skylight
  module Util
    module Inflector
      extend self

      # From https://github.com/rails/rails/blob/f8e5022c73679f41db9bb6743179bab4571fb28e/activesupport/lib/active_support/inflector/methods.rb

      # Tries to find a constant with the name specified in the argument string.
      #
      #   'Module'.constantize     # => Module
      #   'Test::Unit'.constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter
      # whether it starts with "::" or not. No lexical context is taken into
      # account:
      #
      #   C = 'outside'
      #   module M
      #     C = 'inside'
      #     C               # => 'inside'
      #     'C'.constantize # => 'outside', same as ::C
      #   end
      #
      # NameError is raised when the name is not in CamelCase or the constant is
      # unknown.
      def constantize(camel_cased_word)
        names = camel_cased_word.split('::')

        # Trigger a builtin NameError exception including the ill-formed constant in the message.
        Object.const_get(camel_cased_word) if names.empty?

        # Remove the first blank element in case of '::ClassName' notation.
        names.shift if names.size > 1 && names.first.empty?

        names.inject(Object) do |constant, name|
          if constant == Object
            constant.const_get(name)
          else
            candidate = constant.const_get(name)
            next candidate if constant.const_defined?(name, false)
            next candidate unless Object.const_defined?(name)

            # Go down the ancestors to check it it's owned
            # directly before we reach Object or the end of ancestors.
            constant = constant.ancestors.inject do |const, ancestor|
              break const    if ancestor == Object
              break ancestor if ancestor.const_defined?(name, false)
              const
            end

            # owner is in Object, so raise
            constant.const_get(name, false)
          end
        end
      end

      # Tries to find a constant with the name specified in the argument string.
      #
      #   'Module'.safe_constantize     # => Module
      #   'Test::Unit'.safe_constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter
      # whether it starts with "::" or not. No lexical context is taken into
      # account:
      #
      #   C = 'outside'
      #   module M
      #     C = 'inside'
      #     C                    # => 'inside'
      #     'C'.safe_constantize # => 'outside', same as ::C
      #   end
      #
      # +nil+ is returned when the name is not in CamelCase or the constant (or
      # part of it) is unknown.
      #
      #   'blargle'.safe_constantize  # => nil
      #   'UnknownModule'.safe_constantize  # => nil
      #   'UnknownModule::Foo::Bar'.safe_constantize  # => nil
      def safe_constantize(camel_cased_word)
        constantize(camel_cased_word)
      rescue NameError => e
        raise unless e.message =~ /(uninitialized constant|wrong constant name) #{const_regexp(camel_cased_word)}$/ ||
          e.name.to_s == camel_cased_word.to_s
      rescue ArgumentError => e
        raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
      end

      private

      # Mount a regular expression that will match part by part of the constant.
      #
      #   const_regexp("Foo::Bar::Baz") # => /(Foo(::Bar(::Baz)?)?|Bar|Baz)/
      #   const_regexp("::")            # => /::/
      #
      # NOTE: We also add each part in singly, because sometimes a search for a missing
      # constant like Skylight::Foo::Bar will return an error just saying Foo was missing
      def const_regexp(camel_cased_word) #:nodoc:
        parts = camel_cased_word.split("::")

        return Regexp.escape(camel_cased_word) if parts.empty?

        regexp = parts.reverse.inject do |acc, part|
          part.empty? ? acc : "#{part}(::#{acc})?"
        end

        "(" + ([regexp] + parts[1..-1]).join('|') + ")"
      end
    end
  end
end
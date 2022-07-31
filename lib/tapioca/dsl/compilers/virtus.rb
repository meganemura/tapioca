# typed: strict
# frozen_string_literal: true

begin
  require "virtus"
rescue LoadError
  return
end

module Tapioca
  module Dsl
    module Compilers
      # `Tapioca::Dsl::Compilers::Virtus` decorates RBI files for all
      # classes that use [`Virtus.model`](https://github.com/solnic/virtus).
      #
      # For example, with the following class:
      #
      # ~~~rb
      # class Shop
      #   include Virtus.model
      #
      #   attribute :name, String
      # end
      # ~~~
      #
      # this compiler will produce an RBI file with the following content:
      # ~~~rbi
      # # typed: true
      #
      # class Shop
      #
      #   sig { returns(T.nilable(::String)) }
      #   def name; end
      #
      #   sig { params(name: T.nilable(::String)).returns(T.nilable(::String)) }
      #   def name=(name); end
      # end
      # ~~~
      class Virtus < Compiler
        extend T::Sig

        # ConstantType = type_member { { fixed: T.all(Class, ::Virtus.model) } }

        sig { override.void }
        def decorate
          attributes = constant.attribute_set
          return if attributes.to_a.empty?

          root.create_path(constant) do |klass|
            attributes.each do |attribute|
              type = type_for(attribute.type)
              generate_method(klass, attribute.name.to_s, type)
            end
          end
        end

        sig { override.returns(T::Enumerable[Module]) }
        def self.gather_constants
          all_classes.select { |klass|
            begin
              source_location = klass.method(:attribute).source_location

              source_location[0].include?("virtus/builder/hook_context.rb")
            rescue NameError
              # puts klass
              nil
            end
          }
        end

        private

        HANDLED_METHOD_TARGETS = T.let(["attribute", "attribute="], T::Array[String])

        # sig { returns(T::Array[[::String, ::String]]) }
        # def attribute_methods_for_constant
        #   patterns = if constant.respond_to?(:attribute_method_patterns)
        #     # https://github.com/rails/rails/pull/44367
        #     T.unsafe(constant).attribute_method_patterns
        #   else
        #     constant.attribute_method_matchers
        #   end
        #   patterns.flat_map do |pattern|
        #     constant.attribute_types.map do |name, value|
        #       next unless handle_method_pattern?(pattern)
        #
        #       [pattern.method_name(name), type_for(value)]
        #     end.compact
        #   end
        # end

        sig { params(pattern: T.untyped).returns(T::Boolean) }
        def handle_method_pattern?(pattern)
          target = if pattern.respond_to?(:method_missing_target)
            # Pre-Rails 6.0, the field is named "method_missing_target"
            T.unsafe(pattern).method_missing_target
          elsif pattern.respond_to?(:target)
            # Rails 6.0+ has renamed the field to "target"
            pattern.target
          else
            # https://github.com/rails/rails/pull/44367/files
            T.unsafe(pattern).proxy_target
          end

          HANDLED_METHOD_TARGETS.include?(target.to_s)
        end

        sig { params(attribute_type: Class).returns(::String) }
        def type_for(attribute_type)
          type = case attribute_type.to_s
          when "Axiom::Types::Object"
            "T.untyped"
          when "Axiom::Types::Integer"
            "::Integer"
          when "Axiom::Types::String"
            "::String"
          when "Axiom::Types::Float"
            "::Float"
          when "Axiom::Types::Time"
            "::Time"
          when "Axiom::Types::Boolean"
            "T::Boolean"
          else
            # we don't want untyped to be wrapped by T.nilable, so just return early
            return "T.untyped"
          end

          as_nilable_type(type)
        end

        sig { params(klass: RBI::Scope, attribute_name: String, type: String).void }
        def generate_method(klass, attribute_name, type)
          klass.create_method(attribute_name, return_type: type)

          parameter = create_param("value", type: type)
          klass.create_method(
            "#{attribute_name}=",
            parameters: [parameter],
            return_type: type
          )
        end
      end
    end
  end
end

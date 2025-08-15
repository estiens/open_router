# frozen_string_literal: true

module OpenRouter
  class SchemaValidationError < Error; end

  class Schema
    attr_reader :name, :strict, :schema

    def initialize(name, schema_definition = {}, strict: true)
      @name = name
      @strict = strict
      raise ArgumentError, "Schema definition must be a hash" unless schema_definition.is_a?(Hash)

      @schema = schema_definition
      validate_schema!
    end

    # Class method for defining schemas with a DSL
    def self.define(name, strict: true, &block)
      builder = SchemaBuilder.new
      builder.instance_eval(&block) if block_given?
      new(name, builder.to_h, strict:)
    end

    # Convert to the format expected by OpenRouter API
    def to_h
      {
        name: @name,
        strict: @strict,
        schema: @schema
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    # Validate data against this schema (requires json-schema gem)
    def validate(data)
      return true unless validation_available?

      validator = JSON::Validator.new(@schema, data)
      validator.validate
    end

    # Get validation errors for data (requires json-schema gem)
    def validation_errors(data)
      return [] unless validation_available?

      JSON::Validator.fully_validate(@schema, data)
    end

    # Check if JSON Schema validation is available
    def validation_available?
      !!defined?(JSON::Validator)
    end

    private

    def validate_schema!
      raise ArgumentError, "Schema name is required" if @name.nil? || @name.empty?
      raise ArgumentError, "Schema must be a hash" unless @schema.is_a?(Hash)
    end

    # Internal class for building schemas with DSL
    class SchemaBuilder
      def initialize
        @schema = {
          type: "object",
          properties: {},
          required: []
        }
        @strict_mode = true
      end

      def strict(value = true)
        @strict_mode = value
        additional_properties(!value) if value
      end

      def additional_properties(allowed = true)
        @schema[:additionalProperties] = allowed
      end

      def no_additional_properties
        additional_properties(false)
      end

      def property(name, type, required: false, description: nil, **options)
        prop_def = { type: type.to_s }
        prop_def[:description] = description if description
        prop_def.merge!(options)

        @schema[:properties][name] = prop_def
        mark_required(name) if required
      end

      def string(name, required: false, description: nil, **options)
        property(name, :string, required:, description:, **options)
      end

      def integer(name, required: false, description: nil, **options)
        property(name, :integer, required:, description:, **options)
      end

      def number(name, required: false, description: nil, **options)
        property(name, :number, required:, description:, **options)
      end

      def boolean(name, required: false, description: nil, **options)
        property(name, :boolean, required:, description:, **options)
      end

      def array(name, required: false, description: nil, items: nil, &block)
        array_def = { type: "array" }
        array_def[:description] = description if description

        if items
          array_def[:items] = items
        elsif block_given?
          items_builder = ItemsBuilder.new
          items_builder.instance_eval(&block)
          array_def[:items] = items_builder.to_h
        end

        @schema[:properties][name] = array_def
        mark_required(name) if required
      end

      def object(name, required: false, description: nil, &block)
        object_def = {
          type: "object",
          properties: {},
          required: []
        }
        object_def[:description] = description if description

        if block_given?
          object_builder = SchemaBuilder.new
          object_builder.instance_eval(&block)
          nested_schema = object_builder.to_h
          object_def[:properties] = nested_schema[:properties]
          object_def[:required] = nested_schema[:required]
          object_def[:additionalProperties] = nested_schema[:additionalProperties] if nested_schema.key?(:additionalProperties)
        end

        @schema[:properties][name] = object_def
        mark_required(name) if required
      end

      def required(*field_names)
        field_names.each { |name| mark_required(name) }
      end

      def to_h
        @schema
      end

      private

      def mark_required(name)
        @schema[:required] << name unless @schema[:required].include?(name)
      end
    end

    # Internal class for building array items
    class ItemsBuilder
      def initialize
        @items = {}
      end

      def string(description: nil, **options)
        @items = { type: "string" }
        @items[:description] = description if description
        @items.merge!(options)
      end

      def integer(description: nil, **options)
        @items = { type: "integer" }
        @items[:description] = description if description
        @items.merge!(options)
      end

      def number(description: nil, **options)
        @items = { type: "number" }
        @items[:description] = description if description
        @items.merge!(options)
      end

      def boolean(description: nil, **options)
        @items = { type: "boolean" }
        @items[:description] = description if description
        @items.merge!(options)
      end

      def object(&block)
        @items = { type: "object", properties: {}, required: [] }

        return unless block_given?

          object_builder = SchemaBuilder.new
          object_builder.instance_eval(&block)
          nested_schema = object_builder.to_h
          @items[:properties] = nested_schema[:properties]
          @items[:required] = nested_schema[:required]
      end

      def to_h
        @items
      end
    end
  end
end

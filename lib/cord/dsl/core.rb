module Cord
  module DSL
    module Core
      extend ActiveSupport::Concern

      included do
        attr_accessor :abstract

        hash_stores %i[default_scopes scopes custom_aliases]
        array_stores %i[alias_columns searchable_columns]

        class << self
          def abstract!
            @abstract = true
          end

          def abstract?
            !!@abstract
          end

          def driver
            assert_not_abstract
            @driver ||= default_scopes.inject(model.all) do |driver, scope|
              apply_scope(driver, *scope)
            end
          end

          def model value = nil
            return nil if abstract?
            value ||= (superclass.model || model_from_api) unless @model
            if value
              raise ArgumentError, 'expected an ActiveRecord model' unless is_model?(value)
              @model = value
              @model.column_names.each do |name|
                sql = %("#{@model.table_name}"."#{name}")
                if (enum = @model.defined_enums[name])
                  sql = %('#{enum.invert.to_json}'::jsonb->#{sql}::text)
                end
                attribute name, sql: sql
              end
              scope :all
            end
            @model
          end

          def resource_name value = nil
            if value
              @resource_name = value
            else
              @resource_name ||= model&.table_name
            end
          end

          def default_scope name = nil, &block
            raise ArgumentError, 'must provide either a name or a block' unless name || block
            default_scopes.add name, &block
          end

          def scope name, &block
            scopes.add name, &block
          end

          attr_writer :context

          def context
            @context ||= ActiveSupport::StringInquirer.new('member')
          end

          def collection
            temp_context = @context
            @context = ActiveSupport::StringInquirer.new('collection')
            yield
            @context = temp_context
          end

          def member
            temp_context = @context
            @context = ActiveSupport::StringInquirer.new('member')
            yield
            @context = temp_context
          end

          def custom_alias name, &block
            custom_aliases.add name, &block
          end
        end
      end

      def driver
        @driver ||= default_scopes.inject(model.all) do |driver, scope|
          apply_scope(driver, *scope)
        end
      end

      def model
        self.class.model
      end

      def resource_name
        self.class.resource_name
      end
    end
  end
end

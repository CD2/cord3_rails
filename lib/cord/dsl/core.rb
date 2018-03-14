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
            unless value || (@model ||= superclass.model)
              value = model_from_api
            end
            if value
              raise ArgumentError, 'expected an ActiveRecord model' unless is_model?(value)
              @model = value

              @model.columns.each do |col|
                name = col.name
                sql = %("#{@model.table_name}"."#{name}")
                sortable = true

                if (enum = @model.defined_enums[name]) # it's an enum
                  sql = %('#{enum.invert.to_json}'::jsonb->#{sql}::text)
                elsif col.type.in? %i[json jsonb] # it's a json field
                  sortable = false
                end

                attribute name, sql: sql, sortable: sortable
              end

              @model.cord_file_accessors.each do |name|
                attribute name
                @model.cord_image_sizes[name].each do |size, _signature|
                  attribute("#{name}__#{size}") { |r| r.send(name)&.get_size(size) }
                end
              end

              scope :all
            end
            @model
          end

          def resource_name value = nil
            if value
              @resource_name = normalize value
            else
              @resource_name ||= model && normalize(model.table_name)
            end
          end

          def default_scope name = nil, &block
            raise ArgumentError, 'must provide either a name or a block' unless name || block
            default_scopes.add (name || block.object_id), &block
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

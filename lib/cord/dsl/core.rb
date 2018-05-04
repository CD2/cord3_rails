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

          def static!
            @static = true
            self.context = :collection
          end

          def static?
            !!@static
          end

          def driver
            assert_not_abstract
            assert_not_static
            return @driver if @driver && (@disable_default_scopes == Cord.disable_default_scopes)
            return @driver = model.all if (@disable_default_scopes = Cord.disable_default_scopes)
            @driver = default_scopes.inject(model.all) do |driver, scope|
              apply_scope(driver, *scope)
            end
          end

          def model value = nil
            return nil if abstract? || static?
            unless value || (@model ||= superclass.model)
              value = model_from_api
            end
            if value
              assert_model(value)
              @model = value

              @model.columns.each do |col|
                name = col.name
                sql = %(#{@model.quoted_table_name}."#{name}")
                sortable = true

                if (enum = @model.defined_enums[name]) # it's an enum
                  sql = hash_to_sql_cases(enum.invert, sql)
                elsif col.type.in? %i[json jsonb] # it's a json field
                  sortable = false
                end

                attribute name, sql: sql, sortable: sortable
              end

              @model.cord_file_accessors.each do |name|
                attribute name
                @model.cord_image_sizes[name].each do |size, _signature|
                  if @model.column_names.include?("#{name}_cache") && !Cord.action_on_missing_image
                    sql = %(#{@model.quoted_table_name}."#{name}_cache"->'#{size}')
                  else
                    sql = nil
                  end
                  attribute("#{name}__#{size}", sql: sql) { |r| r.send(name)&.get_size(size) }
                end
              end

              @model.reflect_on_all_associations.map do |reflection|
                next unless reflection.macro.in? %i[has_many has_one belongs_to]
                associations reflection.name, auto: true
              end

              scope :all
            end
            @model
          end

          def resource_name value = nil
            if value
              @resource_name = normalize value
            else
              return @resource_name if @resource_name
              return @resource_name = nil if abstract?
              return @resource_name = name.chomp('Api').underscore if static?
              @resource_name = model && normalize(model.table_name.gsub('.', '_'))
            end
          end

          def default_scope name = nil, &block
            raise ArgumentError, 'must provide either a name or a block' unless name || block
            default_scopes.add (name || block.object_id), &block
          end

          def scope name, &block
            scopes.add name, &block
          end

          def context= value
            @context = ActiveSupport::StringInquirer.new(value.to_s)
          end

          def context
            @context ||= ActiveSupport::StringInquirer.new('member')
          end

          def collection
            temp_context = @context
            self.context = :collection
            yield
            @context = temp_context
          end

          def member
            temp_context = @context
            self.context = :member
            yield
            @context = temp_context
          end

          def custom_alias name, &block
            custom_aliases.add name, &block
          end
        end
      end

      def driver
        assert_not_abstract
        assert_not_static
        return @driver if @driver && (@disable_default_scopes == Cord.disable_default_scopes)
        return @driver = model.all if (@disable_default_scopes = Cord.disable_default_scopes)
        @driver = default_scopes.inject(model.all) do |driver, scope|
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

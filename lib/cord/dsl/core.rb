module Cord
  module DSL
    module Core
      extend ActiveSupport::Concern

      included do
        include Cord::Stores

        hash_stores %i[
          default_scopes scopes attributes macros meta_attributes member_actions collection_actions
          custom_aliases
        ]

        array_stores %i[
          default_attributes alias_columns searchable_columns
        ]

        def self.driver
          @driver ||= default_scopes.inject(model.all) do |driver, scope|
            apply_scope(driver, *scope)
          end
        end

        delegate :driver, to: :class

        class << self
          def model value = nil
            value ||= model_from_api unless @model
            if value
              raise ArgumentError, 'expected an ActiveRecord model' unless is_model?(value)
              @model = value
              @model.column_names.each { |name| attribute name }
              default_attributes :id
              scope :all
            end
            @model
          end

          def resource_name value = nil
            if value
              @resource_name = value
            else
              @resource_name ||= model.table_name
            end
          end

          def default_scope name = nil, &block
            raise ArgumentError, 'must provide either a name or a block' unless name || block
            default_scopes.add name, block
          end

          def scope name, &block
            scopes.add name, block
          end

          def attribute name, options = {}, &block
            attributes.add name, block
            meta name, options
          end

          def macro name, options = {}, &block
            raise ArgumentError, 'macros require a block' unless block
            name = normalize(name)
            macros[name] = block
            meta name, options
          end

          DEFAULT_META = { children: [], joins: [], references: [], sql: nil }

          def meta name, opts = {}
            options = opts.to_options
            options.assert_valid_keys(:children, :joins, :parents, :references, :sql)
            name = normalize(name)
            Array.wrap(options[:parents]).each { |parent| self.meta parent, children: name }
            meta = meta_attributes[name] ||= DEFAULT_META.deep_dup
            meta[:children] += Array.wrap(options[:children]).map { |x| normalize(x) }
            meta[:joins] += Array.wrap(options[:joins])
            meta[:references] += Array.wrap(options[:references]).map { |x| find_api_name(x) }
            meta[:sql] = options[:sql]
            meta
          end

          def action name, &block
            context.member? ? member_actions.add(name, block) : collection_actions.add(name, block)
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
            custom_aliases.add name, block
          end
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

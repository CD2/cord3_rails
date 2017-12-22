module Cord
  module DSL
    extend ActiveSupport::Concern

    included do

      undelegated_methods = methods

      class << self
        def default_scopes
          @default_scopes ||= {}
        end

        def scopes
          @scopes ||= {}
        end

        def attributes
          @attributes ||= {}
        end

        def macros
          @macros ||= {}
        end

        def meta_attributes
          @meta_attributes ||= {}
        end

        def member_actions
          @member_actions ||= {}
        end

        def collection_actions
          @collection_actions ||= {}
        end

        def driver
          default_scopes.inject(model.all) do |driver, scope|
            apply_scope(driver, *scope)
          end
        end
      end

      delegate *(methods - undelegated_methods), to: :class

      class << self
        def model value = nil
          if value
            raise ArgumentError, 'expected an ActiveRecord model' unless is_model?(value)
            @model = value
            @model.column_names.each { |name| attribute name }
            default_attributes @model.column_names
          end
          @model
        end

        def default_attributes *values
          @default_attributes ||= []
          @default_attributes += values.flatten if values.any?
          @default_attributes
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
          name = normalize(name)
          default_scopes[name] = block || ->(x){ x.send(name) }
        end

        def scope name, &block
          name = normalize(name)
          scopes[name] = block || ->(x){ x.send(name) }
        end

        def attribute name, options = {}, &block
          name = normalize(name)
          attributes[name] = block || ->(x){ x.send(name) }
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
          meta = meta_attributes[name] ||= DEFAULT_META
          meta[:children] += Array.wrap(options[:children]).map { |x| normalize(x) }
          meta[:joins] += Array.wrap(options[:joins])
          meta[:references] += Array.wrap(options[:references]).map { |x| find_api(x) }
          meta[:sql] = options[:sql]
          meta
        end

        def action name, &block
          name = normalize(name)
          context == :member ? member_actions[name] = block : collection_actions[name] = block
        end

        attr_writer :context

        def context
          @context ||= :member
        end

        def collection
          temp_context = @context
          @context = :collection
          yield
          @context = temp_context
        end

        def member
          temp_context = @context
          @context = :member
          yield
          @context = temp_context
        end
      end

      def model
        self.class.model
      end

      def resource_name
        self.class.resource_name
      end

      def default_attributes
        self.class.default_attributes
      end
    end
  end
end

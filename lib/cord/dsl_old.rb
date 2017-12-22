module Cord
  module DSL

    def self.included(base)
      base.extend ClassMethods
    end

    def driver
      return @driver if @driver
      block = self.class.instance_variable_get(:@driver) || raise('No api driver set')
      @driver = instance_exec &block
    end

    def model
      return driver if driver <= ActiveRecord::Base
      driver.model
    end

    def postgres_rendering_enabled?
      self.class.postgres_rendering_enabled?
    end

    def sorts
      self.class.sorts
    end

    def searchable_columns
      self.class.searchable_by
    end

    def columns
      self.class.columns
    end

    def ignore_columns
      self.class.ignore_columns.map(&:to_s)
    end

    def scopes
      self.class.scopes
    end

    def attributes
      self.class.attributes
    end

    def member_actions
      self.class.member_actions
    end

    def collection_actions
      self.class.collection_actions
    end

    def attribute_names
      attributes.keys
    end

    def secondary_keys
      self.class.secondary_keys
    end

    def join_dependencies
      self.class.join_dependencies
    end

    def sql_attributes
      self.class.sql_attributes
    end

    def resource_name
      self.class.given_resource_name || model.table_name
    end

    def before_actions
      self.class.before_actions
    end

    module ClassMethods


      def abstract?
        @abstract || false
      end

      def abstract!
        @abstract = true
      end

      def driver driver=nil, &block
        block = -> { driver } unless block.present?
        @driver = block
      end

      def columns *cols
        @columns ||= []
        @columns += cols
      end

      def ignore_columns *cols
        @ignore_columns ||= []
        @ignore_columns += cols
      end

      def scopes
        @scopes ||= {}.with_indifferent_access
      end

      def scope name, &block
        block ||= ->(x){ x.send(name) }
        scopes[name] = block
      end

      def secondary_keys
        @secondary_keys ||= []
      end

      def secondary_key name
        @secondary_keys = secondary_keys + [name]
      end

      def join_dependencies
        @join_dependencies ||= {}.with_indifferent_access
      end

      def join_dependency name, association
        join_dependencies[name] = association
      end

      def sql_attributes
        @sql_attributes ||= {}.with_indifferent_access
      end

      def sql_attribute name, sql
        sql_attributes[name] = sql
      end

      def sorts
        @sorts ||= {}
      end

      def sort name, &block
        block ||= ->(driver, dir){ driver.order(name => dir) }
        sorts[name.to_s] = block
      end

      def searchable_by *cols
        @searchable_columns ||= []
        @searchable_columns += cols
      end

      # has_many :books
      # book_ids, books, book_count
      def has_many association_name, opts = {}
        options = { joins: association_name }.merge(opts.to_options)
        single = association_name.to_s.singularize

        self.attribute association_name, options
        self.attribute "#{single}_ids", options do |record|
          record.send(association_name).ids
        end
        self.attribute "#{single}_count", options do |record|
          record.send(association_name).size
        end

        if options[:joins] && !options.has_key?(:sql)
          sql_attribute "#{single}_ids", %(
            coalesce(array_agg(:table.id) FILTER (WHERE :table.id IS NOT NULL), '{}')
          )
          sql_attribute "#{single}_count", 'COUNT(:table.id)'
        end
      end

      # has_one :token
      # adds token
      def has_one association_name, opts = {}
        options = { joins: association_name }.merge(opts.to_options)

        self.attribute association_name, options
        self.attribute "#{association_name}_id", options do |record|
          record.send(association_name)&.id
        end

        if options[:joins] && !options.has_key?(:sql)
          sql_attribute "#{association_name}_id", '(array_agg(:table.id))[1]'
        end
      end

      def belongs_to association_name, opts = {}
        options = { joins: association_name }.merge(opts.to_options)

        self.attribute association_name, options
      end

      def attributes
        @attributes ||= HashWithIndifferentAccess.new
      end

      def attribute *names, &block
        options = names.extract_options!.to_options
        options.assert_valid_keys :joins, :sql
        joins = options.fetch(:joins, false)
        sql = options.fetch(:sql, nil)

        unless names.one?
          raise ArgumentError, 'may only provide a block for single attributes' if block
          raise ArgumentError, 'may only provide an sql option for single attributes' if sql
        end

        names.each do |name|
          attributes[name] = block || ->(record){ record.send(name) }

          self.join_dependency name, joins if joins
          self.sql_attribute name, sql if sql
        end
      end

      def permitted_params *args
        return @permitted_params || [] if args.empty?
        @permitted_params = args
      end

      def collection_actions
        @collection_actions ||= HashWithIndifferentAccess.new
      end

      def action name, &block
        check_name!(name)
        collection_actions[name] = block
      end

      def member_actions
        @member_actions ||= HashWithIndifferentAccess.new
      end

      def action_for name, &block
        check_name!(name)
        member_actions[name] = block
      end

      def resource_name value
        @resource_name = value
      end

      def given_resource_name
        @resource_name
      end

      def before_actions
        @before_actions ||= (self == Cord::BaseApi ? {} : superclass.before_actions.deep_dup)
      end

      def before_action name, opts = {}, &block
        name = name.to_sym
        only, except = process_before_action_options opts
        unless before_actions[name]
          before_actions[name] = {
            block: (block || eval("proc { #{name} }")), only: only, except: except
          }
          return
        end
        raise "Before action '#{name}' already exists with a different block" if block
        return before_actions[name][:only] += only if before_actions[name][:only] && only
        return before_actions[name][:except] += except if before_actions[name][:except] && except
        raise %(
          You have defined a before action with '#{before_actions[name][:only] ? 'only' : 'except'}',
          then attempted to extend it with '#{only ? 'only' : 'except'}'.
          I am unsure of the correct behaviour here.
        ).squish
      end

      def skip_before_action name, opts = {}
        raise "Before action \"#{name}\" is undefined" unless before_actions[name]
        only, except = process_before_action_options opts
        if only
          if before_actions[name][:only]
            before_actions[name][:only] -= only
          else
            before_actions[name][:except] += only
          end
        elsif except
          if before_actions[name][:only]
            before_actions[name][:only] &= except
          else
            before_actions[name][:only] = except - before_actions[name].delete(:except)
          end
        else
          before_actions.delete(name)
        end
      end

      def process_before_action_options opts
        options = opts.to_options
        options.assert_valid_keys :only, :except
        raise 'Provide either :only or :except, not both' if options[:only] && options[:except]
        if options[:only]
          only = Array.wrap(options[:only])
          except = nil
        else
          only = nil
          except = Array.wrap(options[:except])
        end
        [only, except]
      end

      def check_name! name
        raise "Action name \"#{name}\" is already in use" if reserved_name?(name)
      end

      def reserved_name? name
        name == 'get' || name == 'ids'
      end

      def postgres_rendering_enabled?
        return @postgres_rendering_enabled unless @postgres_rendering_enabled.nil?
        @postgres_rendering_enabled = Cord.enable_postgres_rendering
      end

      def enable_postgres_rendering value
        @postgres_rendering_enabled = value
      end
    end
  end
end

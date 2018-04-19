module Cord
  module DSL
    module Keywords
      extend ActiveSupport::Concern

      included do
        hash_stores %i[attributes macros meta_attributes]
        array_stores %i[default_attributes blacklisted_attributes]

        class << self
          previous_store_methods = {}
          %i[attributes macros meta_attributes].each do |s|
            previous_store_methods[s] = instance_method(s)
            define_method(s) { model; previous_store_methods[s].bind(self).call }
          end

          def attribute name, options = {}, &block
            return if blacklisted_attributes.include? normalize(name)
            attributes.add name, &block
            meta name, options
          end

          def macro name, options = {}, &block
            raise ArgumentError, 'macros require a block' unless block
            name = normalize(name)
            macros[name] = block
            meta name, options
          end

          DEFAULT_META = {
            children: [], references: [], joins: nil, sql: nil, sortable: true, cached: nil
          }

          def meta name, opts = {}
            options = opts.to_options
            options.assert_valid_keys(
              :children, :joins, :parents, :references, :sql, :sortable, :cached
            )
            name = normalize(name)
            Array.wrap(options[:parents]).each { |parent| self.meta parent, children: name }
            meta = meta_attributes[name] ||= DEFAULT_META.deep_dup
            meta[:children] += Array.wrap(options[:children]).map { |x| normalize(x) }
            meta[:references] += Array.wrap(options[:references]).map { |x| find_api_name(x) }
            meta[:joins] = options[:joins]
            meta[:sql] = options[:sql]
            meta[:sortable] = options[:sortable] unless options[:sortable].nil?
            if options[:cached].is_a?(ActiveSupport::Duration)
              meta[:cached] = options[:cached]
            else
              meta[:cached] = options[:cached] ? Cord.default_cache_lifespan : nil
            end
            meta
          end

          def blacklist_attributes *names
            attributes.remove names
            blacklisted_attributes.add names
          end
        end
      end

      private

      def requested? keyword
        keyword = normalize(keyword)
        @keywords.include? keyword
      end

      def render_attribute name
        name = normalize(name)
        @record_json[name] = get_attribute(name)
      end

      def get_attribute name
        name = normalize(name)
        if @calculated_attributes.has_key?(name)
          @calculated_attributes[name]
        else
          calculate_attribute(name)
        end
      end

      def calculate_attribute(name)
        name = normalize(name)
        raise ArgumentError, "undefined attribute: '#{name}'" unless attributes[name]
        begin
          @calculated_attributes[name] = instance_exec(@record, &attributes[name])
        rescue Exception => e
          error_log e
          @record_json[:_errors] ||= []
          @record_json[:_errors] << e
          nil
        end
      end

      def perform_macro(name, *args)
        name = normalize(name)
        raise ArgumentError, "undefined macro: '#{name}'" unless macros[name]
        begin
          instance_exec(*args, &macros[name])
        rescue Exception => e
          error_log e
          @record_json[:_errors] ||= []
          @record_json[:_errors] << e
        end
      end

      def keyword_missing name
        e = "'#{name}' does not match any keywords defined for #{self.class}"
        error_log e
        @record_json[:_errors] ||= []
        @record_json[:_errors] << e
      end

      def type_of_keyword name
        name = normalize(name)
        return :macro if macros.has_key?(name)
        if attributes.has_key?(name)
          return :virtual if meta_attributes.dig(name, :joins)
          return :field if meta_attributes.dig(name, :sql)
          :attribute
        end
      end
    end
  end
end

require_relative 'errors'
require_relative 'helpers'
require_relative 'json_string'
require_relative 'promise'
require_relative 'stores'
require_relative 'sql_string'

Dir[Cord::Engine.root + './lib/cord/dsl/**/*.rb'].each { |file| require file }

module Cord
  class BaseApi
    include Stores

    include DSL::Core

    include DSL::Actions
    include DSL::Associations
    include DSL::BeforeActions
    include DSL::CRUD
    include DSL::Keywords

    include Helpers

    attr_reader :controller

    abstract!

    self.default_attributes = [:id]
    self.crud_callbacks = CRUD_CALLBACKS.map { |x| [x, proc {}]}.to_h

    def render_ids scopes, search = nil, sort = nil
      result = {}
      records = alias_driver(driver)

      if sort.present?
        order_values = records.order_values
        records = apply_sort(records.except(:order), sort, result: result)
        records = records.order(order_values)
      end

      records = apply_search(records, search) if search.present?

      scopes.each do |name|
        name = normalize(name)
        unless self.class.scopes[name]
          e = "'#{name}' scope not defined for #{self.class.name}"
          error_log e
          result[:_errors] ||= {}
          result[:_errors][name] = e
          next
        end
        begin
          query = apply_scope(records, name, self.class.scopes[name]).order(:id)
          result[name] = pluck_to_json(query, :id)
        rescue Exception => e
          error_log e
          result[:_errors] ||= {}
          result[:_errors][name] = e
        end
      end
      result
    end

    def render_records ids, keywords = []
      @records_json = []
      ids = prepare_ids(ids)
      @keywords, @options = prepare_keywords(keywords)
      records = driver.where(id: ids.to_a)
      valid_caches = []
      invalid_caches = []

      if model_supports_caching?
        cache_selects = @keywords.map do |k|
          next if type_of_keyword(k) == :field
          next unless cache_lifespan = meta_attributes.dig(k, :cached)
          result = SQLString.new %(
            EVERY((cord_cache -> :key ->> 'time')::timestamp > greatest(:time, updated_at)) AS #{k}
          )
          result.compact.assign(key: k, time: cache_lifespan.ago)
        end

        if cache_selects.any?
          cache_check = model.where(id: records).select(cache_selects.compact.join(', '))
          valid_caches, invalid_caches = cache_check.raw[0].partition { |_k, v| v }.map do |x|
            x.map &:first
          end
        end
      end

      if @keywords.all? { |x| type_of_keyword(x).in?(%i[field virtual]) || x.in?(valid_caches) }
        # Use Postgres to generate the JSON

        selects = []
        joins = []

        @keywords.each do |keyword|
          if keyword.in?(valid_caches)
            selects << %(
              "#{model.table_name}"."cord_cache" -> '#{keyword}' -> 'value' AS "#{keyword}"
            ).squish
            next
          end

          if meta_attributes[keyword][:joins]
            joins << meta_attributes[keyword][:joins]
          end
          selects << %(#{meta_attributes[keyword][:sql]} AS "#{keyword}")
        end

        records = alias_driver(records).joins(joins).select(selects)
        @records_json, missing_ids = driver_to_json_with_missing_ids(records, ids.to_a)

        update_record_caches(invalid_caches, @records_json) if invalid_caches.any?
      else
        # Use Ruby to generate the JSON
        missing_ids = ids.dup

        records.each do |record|
          result = render_record(record)
          @records_json << result
          missing_ids.delete result['id'].to_s
        end

        if invalid_caches.any?
          update_record_caches(invalid_caches, @records_json) if invalid_caches.any?
        end
      end

      @keywords, @options = nil
      if missing_ids.any?
        error_log RecordNotFound.new(missing_ids)
        @records_json += missing_ids.map { |id| { id: id, _errors: ['not found'] } }
      end
      @records_json
    end

    private

    def initialize controller = nil
      assert_not_abstract
      @controller = controller
    end

    def render_record record
      @record = record
      @record_json = {}
      @calculated_attributes = {}
      @keywords.each do |keyword|
        case type_of_keyword(keyword)
        when :macro
          perform_macro(keyword, *(@options[keyword] || []))
        when :attribute, :field, :virtual
          @record_json[keyword] = render_attribute(keyword)
        else
          keyword_missing(keyword)
        end
      end
      result = @record_json
      @record, @record_json, @calculated_attributes = nil
      result
    end

    def prepare_keywords keywords
      options = {}
      keywords = Array.wrap(keywords | default_attributes).map do |x|
        if x.is_a?(Hash)
          x.map do |macro_name, macro_options|
            macro_name = normalize(macro_name)
            options[macro_name] = Array.wrap(macro_options)
            macro_name
          end
        else
          normalize(x)
        end
      end
      keywords = keywords.flatten.uniq
      i = 0
      while keywords[i] do
        keyword = keywords[i]
        keywords += (meta_attributes.dig(keyword, :children) || []) - keywords
        i += 1
      end
      [keywords, options]
    end

    def prepare_ids ids
      filter_ids = Set.new
      aliases = {}

      ids = ids.map do |x|
        x = normalize(x)
        if custom_aliases.has_key?(x)
          result = instance_eval(&custom_aliases[x])
          result = result.id if is_record?(result)
          result = normalize(result)
          filter_ids << result
          aliases[x] = result.to_i
          nil
        else
          x
        end
      end

      ids.compact!

      alias_columns.each do |key|
        discovered_aliases = []
        key = normalize(key)
        driver.where(key => ids).pluck('id', key).each do |id, value|
          id = normalize(id)
          aliases[value] = id.to_i
          filter_ids << id
          discovered_aliases << value
        end
        ids -= discovered_aliases
      end
      filter_ids += ids

      render_aliases(self.class, aliases) if controller

      filter_ids
    end

    def apply_sort(driver, sort, result: {})
      assert_driver(driver)
      field, dir = sort.downcase.split(' ')
      unless dir.in?(%w[asc desc])
        e = "'#{dir}' is not a valid sort direction, expected 'asc' or 'desc'"
        error_log e
        result[:_errors] ||= {}
        result[:_errors][:_sort] = e
      end
      if type_of_keyword(field).in?(%i[field virtual]) && meta_attributes[field][:sortable]
        meta = meta_attributes[field]
        driver.joins(meta[:joins]).order(%(#{meta[:sql]} #{dir.upcase}))
      else
        e = "'#{field}' does not match any sortable attributes"
        error_log e
        result[:_errors] ||= {}
        result[:_errors][:_sort] = e
        driver
      end
    end

    def apply_search(driver, search)
      assert_driver(driver)
      conditions = searchable_columns.map do |col|
        col = meta_attributes.dig(normalize(col), :sql) || col
        "#{col} ILIKE :term"
      end
      driver.where(conditions.join(' OR '), term: "%#{search}%")
    end

    def update_record_caches fields, records_json = []
      api = self.class
      return if api.cache_updating?

      time = Time.current
      records_json = records_json.to_a

      new_cache_data = records_json.map do |record_json|
        result = { id: record_json['id'], cord_cache: {} }
        fields.each { |f| result[:cord_cache][f] = { value: record_json[f], time: time } }
        result[:cord_cache] = result[:cord_cache].to_json
        SQLString.new("(:id, :cord_cache::jsonb)").assign(result)
      end

      query = SQLString.new <<-SQL
        UPDATE #{model.table_name}
        SET cord_cache = #{model.table_name}.cord_cache || new_cache_data.cord_cache
        FROM (VALUES #{new_cache_data.join(',')}) AS new_cache_data(id, cord_cache)
        WHERE #{model.table_name}.id = new_cache_data.id
      SQL

      api.cache_updating!
      query.compact.run_async.finally { api.cache_updated! }
    end

    def self.cache_updating?
      @cache_updating_lock ||= Mutex.new
      @cache_updating_lock.synchronize { !!@cache_updating }
    end

    def self.cache_updating!
      @cache_updating_lock ||= Mutex.new
      @cache_updating_lock.synchronize { @cache_updating = true }
    end

    def self.cache_updated!
      @cache_updating_lock ||= Mutex.new
      @cache_updating_lock.synchronize { @cache_updating = false }
    end

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    def respond_to_missing? method_name, *args, &block
      controller.respond_to?(method_name)
    end
  end
end

require_relative 'errors'
require_relative 'helpers'
require_relative 'json_string'
require_relative 'stores'

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
      records = driver

      if sort.present?
        order_values = records.order_values
        records = apply_sort(records.except(:order), sort)
        records = records.order(order_values).order(:id)
      end

      records = apply_search(records, search) if search.present?

      scopes.each do |name|
        name = normalize(name)
        unless self.class.scopes[name]
          result[:_errors] ||= {}
          result[:_errors][name] = "'#{name}' scope not defined for #{self.class.name}"
          next
        end
        begin
          result[name] = apply_scope(records, name, self.class.scopes[name]).ids
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

      if @keywords.all? { |x| type_of_keyword(x) == :field }
        # Use Postgres to generate the JSON
        joins = @keywords.map { |keyword| meta_attributes[keyword][:joins] }.compact
        selects = @keywords.map { |keyword| %(#{meta_attributes[keyword][:sql]} AS "#{keyword}") }
        records = records.joins(joins).select(selects)
        @records_json, ids = driver_to_json_with_missing_ids(records, ids.to_a)
      else
        # Use Ruby to generate the JSON
        records.each do |record|
          result = render_record(record)
          @records_json << result
          ids.delete result['id'].to_s
        end
      end

      @keywords, @options = nil
      @records_json += ids.map { |id| { id: id, _errors: ['not found'] } } if ids.any?
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
        when :attribute, :field
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

    def apply_sort(driver, sort)
      assert_driver(driver)
      field, dir = sort.downcase.split(' ')
      unless dir.in?(%w[asc desc])
        raise ArgumentError, "'#{dir}' is not a valid sort direction, expected 'asc' or 'desc'"
      end
      if type_of_keyword(field) == :field
        meta = meta_attributes[field]
        driver.joins(meta[:joins]).order(%(#{meta[:sql]} #{dir.upcase}))
      else
        error "unknown sort #{field}"
        driver
      end
    end

    def apply_search(driver, search)
      assert_driver(driver)
      condition = searchable_columns.map { |col| "#{col} ILIKE :term" }.join ' OR '
      driver.where(condition, term: "%#{search}%")
    end

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    def respond_to_missing? method_name, *args, &block
      controller.respond_to?(method_name)
    end
  end
end

require_relative 'crud'
require_relative 'helpers'
require_relative 'json_string'
require_relative 'stores'

Dir[Cord::Engine.root + './lib/cord/dsl/**/*.rb'].each { |file| require file }

module Cord
  class BaseApi
    include DSL::Actions
    include DSL::Associations
    include DSL::Core
    include DSL::Keywords

    include CRUD
    include Helpers

    attr_reader :controller

    def render_ids scopes, search = nil, sort = nil
      result = { _errors: {} }
      records = driver
      records = apply_sort(records, sort) if sort.present?
      records = apply_search(records, search, searchable_columns) if search.present?
      scopes.each do |name|
        name = normalize(name)
        unless self.class.scopes[name]
          result[:_errors][name] = "'#{name}' scope not defined for #{self.class.name}"
          next
        end
        begin
          result[name] = apply_scope(records, name, self.class.scopes[name]).ids
        rescue Exception => e
          error_log e
          result[:_errors][name] = e
        end
      end
      result
    end

    def render_records ids, keywords = []
      @records_json = []
      ids = prepare_ids(ids)
      records = driver.where(id: ids.to_a)
      records.each do |record|
        result = render_record(record, keywords)
        @records_json << result
        ids.delete result['id'].to_s
      end
      @records_json += ids.map { |id| { id: id, _errors: ['not found'] } }
    end

    def render_record record, keywords = []
      @keywords, @options = prepare_keywords(keywords)
      @record = record
      @record_json = { _errors: [] }
      @calculated_attributes = {}
      @keywords.each do |keyword|
        if macros.has_key?(keyword)
          perform_macro(keyword, *(@options[keyword] || []))
        elsif attributes.has_key?(keyword)
          @record_json[keyword] = render_attribute(keyword)
        else
          keyword_missing(keyword)
        end
      end
      result = @record_json
      @record, @record_json, @calculated_attributes, @keywords, @options = nil
      result
    end

    def perform_bulk_member_action ids, name, data = {}, errors: []
      @actions_json = []
      records = driver.where(id: ids)
      records.each do |record|
        @actions_json << perform_member_action(record, name, data, errors: errors)
      end
      @actions_json
    end

    def perform_member_action record, name, data = {}, errors: []
      temp_record = @record
      @record = record
      result = perform_action(name, data, errors: errors)
      @record = temp_record
      result
    end

    def perform_collection_action name, data = {}, errors: []
      perform_action(name, data, errors: errors)
    end

    private

    def initialize controller = nil
      @controller = controller
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

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    def respond_to_missing? method_name, *args, &block
      controller.respond_to?(method_name)
    end
  end
end

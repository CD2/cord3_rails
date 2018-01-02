require_relative 'crud'
require_relative 'helpers'
require_relative 'json_string'

Dir[Cord::Engine.root + './lib/cord/dsl/**/*.rb'].each { |file| require file }

module Cord
  class BaseApi
    include DSL::Actions
    include DSL::Associations
    include DSL::Core
    include DSL::Records

    include CRUD
    include Helpers

    attr_reader :controller

    def render_ids scopes, search = nil, sort = nil
      result = {}
      records = driver
      records = apply_sort(records, sort) if sort.present?
      records = apply_search(records, search, searchable_columns) if search.present?
      scopes.each do |name|
        name = normalize(name)
        result[name] = apply_scope(records, name, self.class.scopes[name]).ids
      end
      result
    end

    def render_records ids, keywords = []
      @records_json = []
      records = driver.where(id: ids)
      records.each { |record| @records_json << render_record(record, keywords) }
      @records_json
    end

    def render_record record, keywords = []
      @keywords, @options = prepare_keywords(keywords)
      @record = record
      @record_json = {}
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

    def perform_bulk_member_action ids, name, data = {}
      @actions_json = []
      records = driver.where(id: ids)
      records.each { |record| @actions_json << perform_member_action(record, name, data) }
      @actions_json
    end

    def perform_member_action record, name, data = {}
      @record = record
      result = perform_action(name, data)
      @record = nil
      result
    end

    def perform_collection_action name, data = {}
      perform_action(name, data)
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

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    def respond_to_missing? method_name, *args, &block
      controller.respond_to?(method_name)
    end
  end
end

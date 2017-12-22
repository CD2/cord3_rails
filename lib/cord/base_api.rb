require_relative 'crud'
require_relative 'dsl'
require_relative 'helpers'
require_relative 'json_string'

module Cord
  class BaseApi
    include CRUD
    include DSL
    include Helpers

    attr_reader :controller

    def render_ids scopes, search = nil, sort = nil
      result = {}
      scopes.each do |name|
        name = normalize(name)
        result[name] = apply_scope(driver, name, self.class.scopes[name]).ids
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
      @keywords = prepare_keywords(keywords)
      @record = record
      @record_json = {}
      @keywords.each do |keyword|
        if macros.has_key?(keyword)
          perform_macro(keyword)
        elsif attributes.has_key?(keyword)
          @record_json[keyword] = render_attribute(keyword)
        else
          keyword_missing(keyword)
        end
      end
      result = @record_json
      @record, @record_json, @keywords, @record_json = nil
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
      keywords = keywords | default_attributes
      keywords = keywords.map { |x| normalize(x) }
      # result = []
      # i = 0
      # while keywords[i] do
      #   keywords += meta_attributes.dig(keyword)
      #   i += 1
      # end
    end

    # this is getting pretty confusing, use seperate DSLs:
    # one for defining stuff
    # one for using stuff inside member actions
    # one for using stuff inside collection actions
    # one for using stuff inside macros
    # then move all these private methods to the correct place

    def render data
      raise 'Call to \'render\' after action chain has been halted' if @halted
      @response.merge! data
    end

    def halt! message = nil, status: 401
      return if halted?
      if message
        @response = {}
        error message
      else
        @response = nil
      end
      @halted = true
    end

    def halted?
      !!@halted
    end

    def render_attribute name
      name = normalize(name)
      @record_json[name] = get(name)
    end

    def get attribute
      attribute = normalize(attribute)
      @record_json.has_key?(attribute) ? @record_json[attribute] : calculate_attribute(attribute)
    end

    def calculate_attribute(name)
      name = normalize(name)
      raise ArgumentError, "undefined attribute: '#{name}'" unless attributes[name]
      instance_exec(@record, &attributes[name])
    end

    def perform_macro(name, *args)
      name = normalize(name)
      raise ArgumentError, "undefined macro: '#{name}'" unless macros[name]
      instance_exec(*args, &macros[name])
    end

    def perform_action(name, data)
      name = normalize(name)
      @data = ActionController::Parameters.new(data)
      @response = {}
      if @record
        action = member_actions[name]
        raise ArgumentError, "undefined member action: '#{name}'" unless action
        instance_exec(@record, &action)
      else
        action = collection_actions[name]
        raise ArgumentError, "undefined collection action: '#{name}'" unless action
        instance_exec &action
      end
      result = @response
      @data, @response = nil
      result
    end

    attr_reader :data

    def requested? keyword
      keyword = normalize(keyword)
      @keywords.include? keyword
    end

    def keyword_missing name
      raise NameError, "'#{name}' does not match any keywords defined for #{self.class.name}"
    end

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    def respond_to_missing? method_name, *args, &block
      controller.respond_to?(method_name)
    end
  end
end

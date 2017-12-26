require_relative 'dsl'
require_relative 'crud'

module Cord
  class BaseApiOld
    include DSL
    include CRUD

    def initialize controller, params
      @controller = controller
      @params = params
    end

    def controller
      @controller
    end

    def perform_before_actions action_name
      before_actions.each do |name, before_action|
        next unless (before_action[:only] && before_action[:only].include?(action_name)) ||
        (before_action[:except] && !before_action[:except].include?(action_name))
        api.instance_eval &before_action[:block]
        break if halted?
      end
    end

    def ids
      perform_before_actions(:ids)
      return [@response, @status] if @halted

      dri = params[:sort].present? ? sorted_driver : driver
      dri = search_filter(dri) if params[:search]
      requested_scopes = Array.wrap(params[:scope]).uniq

      requested_scopes = ['all'] unless requested_scopes.any?
      available_scopes = { 'all' => proc(&:itself) }.merge(scopes)

      ids = {}

      requested_scopes.each do |scope|
        raise 'unknown scope' unless (block = available_scopes[scope])
        scoped_dri = instance_exec(dri.all, &block)
        response = ActiveRecord::Base.connection.execute(
          "SELECT array_to_json(array_agg(json.id)) FROM (#{scoped_dri.order(:id).to_sql}) AS json"
        )
        ids[scope] = JSONString.new(response.values.first.first || '[]')
      end

      JSON.generate (resource_name || model.table_name) => { ids: ids }
    end

    def get(options={})
      perform_before_actions(:get)
      return [@response, @status] if halted?

      records = driver.all
      ids, aliases = filter_records(records, options[:ids] || [])

      return [
        { (resource_name || model.table_name) => { records: [] } },
        404
      ] if ids.none?

      records = records.where(id: ids)

      allowed_attributes = if (options[:attributes].present?)
        white_list_attributes(options[:attributes])
      else
        []
      end

      if postgres_rendering_enabled? && allowed_attributes.all? { |x| postgres_renderable?(x) }
        records_json = postgres_render(records, allowed_attributes)
        response_data = {}
        response_data[:records] = records_json
        response_data[:aliases] = aliases if aliases.any?
        return JSON.generate (resource_name || model.table_name) => response_data
      end

      joins = join_dependencies.values_at(*allowed_attributes)
      records = perform_joins(records, joins)

      records_json = []
      records.each do |record|
        if columns.any?
          record_json = record.as_json(
            only: columns, except: ignore_columns
          )
        else
          record_json = record.as_json(
            except: ignore_columns
          )
        end
        allowed_attributes.each do |attr_name|
          record_json[attr_name] = instance_exec(record, &attributes[attr_name])
        end
        records_json.append(record_json)
      end

      response_data = {}
      response_data[:records] = records_json
      response_data[:aliases] = aliases if aliases.any?
      render (resource_name || model.table_name) => response_data

      [@response, @status]
    end

    def fields(options={})
      perform_before_actions(:fields)
      return [@response, @status] if halted?

      records = params[:sort].present? ? sorted_driver : driver
      records = search_filter(records) if params[:search]

      requested_scopes = Array.wrap(params[:scope]).uniq
      requested_scopes = ['all'] unless requested_scopes.any?
      available_scopes = { 'all' => proc(&:itself) }.merge(scopes)

      requested_attributes = (options[:attributes].presence || [])
      allowed_attributes = white_list_fields(requested_attributes)

      fields_json = {}

      requested_scopes.each do |scope|
        raise 'unknown scope' unless (block = available_scopes[scope])
        scoped_records = instance_exec(records.all, &block)
        fields_json[scope] = postgres_render(scoped_records, allowed_attributes, pluck: true)
      end

      response_data = {}
      response_data[:fields] = fields_json

      JSON.generate (resource_name || model.table_name) => response_data
    end

    def sorted_driver
      col, dir = params[:sort].downcase.split(' ')
      unless dir.in?(%w[asc desc])
        error "sort direction must be either 'asc' or 'desc', instead got '#{dir}'"
        return driver
      end
      if (sort_block = self.sorts[col])
        instance_exec(driver, dir, &sort_block)
      elsif col.in?(model.column_names)
        driver.order(col => dir)
      else
        error "unknown sort #{col}"
        driver
      end
    end

    def search_filter(driver)
      condition = searchable_columns.map { |col| "#{col} ILIKE :term" }.join ' OR '
      driver.where(condition, term: "%#{params[:search]}%")
    end

    def perform action_name
      perform_before_actions(action_name.to_sym)
      return [@response, @status] if halted?

      if ids = params[:ids]
        action = member_actions[action_name]
        if (action)
          driver.where(id: ids).find_each do |record|
            instance_exec(record, &action)
            return [@response, @status] if halted?
          end
        else
          error('no action found')
        end
      else
        action = collection_actions[action_name]
        if (action)
          instance_exec &action
        else
          error('no action found')
        end
      end
      [@response, @status]
    end

    def method_missing *args, &block
      controller.send(*args, &block)
    end

    protected

    def params
      @params
    end

    def render data
      raise 'Call to \'render\' after action chain has been halted' if @halted
      @response ||= {}
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
      @status = status if status
      @halted = true
    end

    def halted?
      !!@halted
    end

    def redirect path
      render status: :redirect, url: path
    end

    def error message
      render error: message
    end

    def error_for record, message
      render error_for: { record: record, message: message}
    end

    private

    def white_list_attributes(attrs)
      blacklist = attrs - attribute_names - model.column_names
      raise "Unknown attributes: #{blacklist.join(', ')}" if blacklist.any?
      attrs & attribute_names
    end

    def white_list_fields(requested_attributes)
      blacklist = requested_attributes - postgres_renderable_attributes
      raise "Unknown attributes: #{blacklist.join(', ')}" if blacklist.any?
      (['id'] + requested_attributes) & postgres_renderable_attributes
    end

    def filter_records records, ids
      return [records.none, {}] unless ids.any?
      filter_ids = Set.new
      aliases = {}
      ([:id] + secondary_keys).each do |key|
        records.where(key => ids).pluck(:id, key).each do |id, value|
          aliases[value] = id if value
          filter_ids << id
        end
      end
      [filter_ids.to_a, aliases]
    end

    def perform_joins records, joins
      return records unless joins.any?
      records.includes(*joins).references(*joins)
    end

    def postgres_renderable_attributes
      sql_attributes.keys + model.column_names
    end

    def postgres_renderable? attribute
      return true if attribute.in? model.column_names
      return true if sql_attributes[attribute]
      return false
    end

    def postgres_render(records, attributes, pluck: false)
      if pluck
        attributes = attributes - ignore_columns
      else
        attributes = (model.column_names + attributes) - ignore_columns
      end

      selects = (attributes - sql_attributes.keys - model.defined_enums.keys).map do |x|
        "#{model.table_name}.#{x}"
      end

      model.defined_enums.each do |field, enum|
        next unless attributes.include? field
        selects << %('#{enum.invert.to_json}'::jsonb->#{field}::text AS "#{field}")
      end

      joins = []

      attributes.each do |attribute|
        next unless (sql = sql_attributes[attribute])
        if (join = join_dependencies[attribute])
          joins << join
          table = model.reflect_on_association(join)&.table_name
          sql = sql.gsub(':table', table) if table
        end
        selects << %((#{sql}) AS "#{attribute}")
      end

      if joins.any?
        records = records.left_joins(*joins.uniq).group(:id)
      end

      if selects.any?
        selects = selects.uniq.join(', ')
        records = records.select(selects)
      end

      return JSONString.new('[]') if records.to_sql.blank?

      # if pluck
      #   fields = attributes.map{ |x| "json.#{x}" }.join(', ')
      #   response = ActiveRecord::Base.connection.execute %(
      #     SELECT array_to_json(array_agg(json_build_array(#{fields})))
      #     FROM (#{records.order(:id).to_sql}) AS json
      #   ).squish
      # else
        response = ActiveRecord::Base.connection.execute(
          "SELECT array_to_json(array_agg(json)) FROM (#{records.order(:id).to_sql}) AS json"
        )
      # end

      JSONString.new(response.values.first.first || '[]')
    end

    class JSONString
      def initialize json
        @json = json
      end

      def to_json *args, &block
        @json
      end
    end
  end
end

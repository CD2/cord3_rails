# frozen_string_literal: true

module Cord
  class ActionHandler < Handler
    # {
    #   id: '',
    #   type: 'action',
    #   data: {
    #     api: '',
    #     name: '',
    #     params: {}
    #   }
    # }

    def validate_each(blob)
      return unless (api = validate_api(blob))
      (blob[:data][:params] ||= {}).permit!
      validate_name(api, blob)
    end

    def validate_api(blob)
      api_name = blob[:data][:api] = normalize(blob[:data][:api])

      if api_name.blank?
        error(blob, :server, type: :noApi, message: 'no api specified')
        return nil
      end

      begin
        strict_find_api(api_name)
      rescue NameError => e
        error(blob, :server, type: :noApi, message: e.message)
        nil
      end
    end

    def validate_name(api, blob)
      name = blob[:data][:name] ||= normalize(blob[:data][:name])

      if name.blank?
        error(blob, :server, type: :noAction, message: 'no action specified')
        return false
      end

      member = blob[:data][:params].key? :id

      return true if (member ? api.member_actions : api.collection_actions)[name]

      error(
        blob,
        :server,
        type: :noAction,
        message: "#{name} does not match any #{member ? 'member' : 'collection'} actions on #{api}"
      )

      false
    end

    def process_each(blob)
      api = controller.load_api(blob[:data][:api])

      if blob[:data][:params].key? :id
        perform_member_action(api, blob)
      else
        perform_collection_action(api, blob)
      end
    end

    def perform_member_action(api, blob)
      record = api.driver.find_by(id: blob[:data][:params][:id])
      return error blob, :notFound unless record
      data = api.perform_member_action(
        record,
        blob[:data][:name],
        data: blob[:data][:params].except(:id).to_h,
        errors: e = [],
        before_actions: true,
        nested: false
      )
      e.any? ? handle_errors(blob, e) : render(blob, data)
    end

    def perform_collection_action(api, blob)
      data = api.perform_collection_action(
        blob[:data][:name],
        data: blob[:data][:params].to_h,
        errors: e = [],
        before_actions: true,
        nested: false
      )
      e.any? ? handle_errors(blob, e) : render(blob, data)
    end

    def handle_errors(blob, *errors)
      return unless (error = errors.flatten.find { |e| !e.is_a?(Warning) })
      if error.is_a? ValidationError
        error blob, :validation, JSON.parse(error.message)
      else
        error blob, :server, error.message
      end
    end
  end
end

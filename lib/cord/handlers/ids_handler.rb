# frozen_string_literal: true

module Cord
  class IdsHandler < Handler
    # {
    #   id: '',
    #   type: 'ids',
    #   data: {
    #     api: '',
    #     scope: '',
    #     search?: '',
    #     sort?: '',
    #   }
    # }

    def validate_each(blob)
      return unless (api = validate_api(blob))
      validate_scope(api, blob) && validate_search(api, blob) && validate_sort(api, blob)
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

    def validate_scope(api, blob)
      scope_name = blob[:data][:scope] = normalize(blob[:data][:scope].presence || 'all')
      return true if api.scopes[scope_name]

      error(
        blob,
        :server,
        type: :noScope,
        message: "#{scope_name.inspect} scope not defined for #{api}"
      )

      false
    end

    def validate_search(_api, _blob)
      # TODO
      true
    end

    def validate_sort(_api, _blob)
      # TODO
      true
    end

    def process_each(blob)
      api = controller.load_api(blob[:data][:api])
      data = api.render_ids([blob[:data][:scope]], blob[:data][:search], blob[:data][:sort])
      render blob, data.values[0]
    end
  end
end

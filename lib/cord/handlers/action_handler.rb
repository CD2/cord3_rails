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

    def process_each(blob)
      # TODO: this
      api = controller.load_api(blob['data']['api'])

      data = if blob['data']['params'].key?('id')
               api.perform_member_action(api.driver.find(blob['data']['params']['id']), blob['data']['name'], data: blob['data']['params'].except('id').permit!.to_h)
             else
               api.perform_collection_action(blob['data']['name'], data: blob['data']['params'].permit!.to_h)
             end
      render blob, data
    rescue ValidationError => e
      error blob, :validation, JSON.parse(e.message)
    end
  end
end

module Cord
  class ApiBaseController < ::ApplicationController
    include Helpers

    def respond
      data = Hash.new { |h, k| h[k] = {} }.with_indifferent_access
      Array.wrap(params[:_json]).each do |body|
        body = body.permit!.to_hash.with_indifferent_access
        api = find_api(body[:api])
        data[api] = json_merge(data[api], body)
      end
      @processing_queue = data.to_a
      @cord_response = Hash.new { |h, k| h[k] = { ids: {}, records: [], actions: [], aliases: {} } }
      process_queue

      render json: formatted_response
    end

    def process_queue
      i = 0
      while @processing_queue[i] do
        api, body = @processing_queue[i]
        blob = process_blob(api, body)
        @cord_response[api] = json_merge(@cord_response[api], blob)
        i += 1
      end
    end

    def process_blob api, body
      api = load_api(api)
      blob = {}
      ids = (body[:ids] || []).map { |x|
        [(x[:_id] || '_'), api.render_ids(x[:scopes], x[:query], x[:sort])]
      }.to_h
      blob[:ids] = ids
      blob[:records] = (body[:records] || []).inject([]) do |result, x|
        result + api.render_records(x[:ids], x[:attributes])
      end
      blob[:actions] = (body[:actions] || []).map { |x| cord_process_action(api, x) }
      blob
    end

    def cord_process_action api, body
      begin
        e = []
        if body[:ids]
          result = api.perform_bulk_member_action(body[:ids], body[:name], body[:data], errors: e)
        else
          result = api.perform_collection_action(body[:name], body[:data], errors: e)
        end
        body[:_id] ? { _id: body[:_id], data: result, _errors: e } : { data: result, _errors: e }
      rescue Exception => e
        body[:_id] ? { _id: body[:_id], data: {}, _errors: [e] } : { data: {}, _errors: [e] }
      end
    end

    def perform_actions *args

    end

    def load_ids api, *args

    end

    def load_records api, ids = [], attributes = []
      @processing_queue << [api, { records: [{ ids: ids, attributes: attributes }] }]
    end

    def render_aliases api, aliases
      @cord_response[api][:aliases].merge! aliases
    end

    def formatted_response
      @cord_response.map do |api, data|
        data[:table] = api.resource_name
        data
      end
    end
  end
end

# The response format:
#
# {
#   table: '',
#   ids: { '' => [], _errors: [] },
#   records: [ { id: 0, _errors: [], ... } ],
#   actions: [ { _id: '', data: {}, _errors: [] } ],
#   aliases: { '' => 0 },
#   _errors: []
# }

# The processing format:
#
# {
#   Api => {
#     ids: { '' => [], _errors: [] },
#     records: [ { id: 0, _errors: [], ... } ],
#     actions: [ { _id: '', data: {}, _errors: [] } ],
#     aliases: { '' => 0 },
#     _errors: []
#   }
# }


# actions first to ensure data changes are reflected in response
# then ids, saving the results for use later as variables
# then records:
#  - examine attributes for precedence, eg. ArticlesApi has 'comments' as a requested attribute,
#    try to order than before CommentsApi
#  - finalize order to honour as many precedence constraints
#  - substitute in variables from ids calls
#  - render every api response, each of which having the option of extending the render queue
#  - if there are any remaining queue items (not in our planned order), repeat all record steps

# When a api takes multiple record requests, consider if any are subsets of the others:
#  - eg. { ids: [1], attrs: [:first_name] } < { ids: [1, 2], attrs: [:first_name, :last_name] }

module Cord
  class ApiBaseController < ::ApplicationController
    include Helpers

    def respond
      @cord_response = Hash.new do |h, k|
        h[k] = { ids: {}, records: [], actions: [], aliases: {}, _errors: [] }
      end
      @cord_response[:_errors] = []

      data = Hash.new { |h, k| h[k] = {} }
      Array.wrap(params[:_json]).each do |body|
        body = json_symbolize(body.permit!.to_hash)
        begin
          api = strict_find_api(body[:api])
          data[api] = json_merge(data[api], body)
        rescue Exception => e
          error_log e
          @cord_response[:_errors] << e
        end
      end

      @processing_queue = []
      @queue_position = 0
      @processed_queue_items = []

      data.each do |k, v|
        add_queue_item(k, v)
      end

      process_queue

      render json: formatted_response
    end

    def process_queue
      while @processing_queue[@queue_position] do
        api, body = @processing_queue[@queue_position]
        blob = process_blob(api, body)
        @cord_response[api] = json_merge(@cord_response[api], blob)
        @processed_queue_items << @processing_queue[@queue_position]
        @queue_position += 1
      end
    end

    def process_blob api, body
      begin
        api = load_api(api)
        blob = {}
        blob[:ids] = (body[:ids] || []).inject({}) do |result, x|
          result.merge process_ids(api, x)
        end
        blob[:records] = (body[:records] || []).inject([]) do |result, x|
          result + api.render_records(x[:ids], x[:attributes])
        end
        blob[:actions] = (body[:actions] || []).map do |x|
          cord_process_action(api, x)
        end
        blob
      rescue Exception => e
        error_log e
        { _errors: [e] }
      end
    end

    def cord_process_action api, body
      begin
        e = []
        if body[:ids]
          result = api.perform_bulk_member_action(
            body[:ids],
            body[:name],
            body[:data],
            errors: e,
            before_actions: true
          )
        else
          result = api.perform_collection_action(
            body[:name],
            body[:data],
            errors: e,
            before_actions: true
          )
        end
        body[:_id] ? { _id: body[:_id], data: result, _errors: e } : { data: result, _errors: e }
      rescue Exception => e
        error_log e
        body[:_id] ? { _id: body[:_id], data: {}, _errors: [e] } : { data: {}, _errors: [e] }
      end
    end

    def process_ids api, body
      { (body[:_id] || '_') => api.render_ids(body[:scopes], body[:query], body[:sort]) }
    end

    def load_ids api, *args

    end

    def load_records api, ids = [], attributes = []
      add_queue_item api, { records: [{ ids: ids, attributes: attributes }] }
    end

    def render_aliases api, aliases
      @cord_response[api][:aliases].merge! aliases
    end

    def formatted_response
      result = @cord_response.except(:_errors).map do |api, data|
        data[:table] = api.resource_name
        data
      end
      result << { table: :_errors, _errors: [@cord_response[:_errors]] }
      JSON.generate result
    end

    def add_queue_item api, body
      unless (existing_item = @processing_queue[@queue_position..-1].detect { |x| x[0] == api })
        existing_item = [api, {}]
        @processing_queue << existing_item
      end
      body.each do |k, v|
        next unless k.in? %i[records ids actions]
        existing_item[1][k] ||= []
        next existing_item[1][k] += v unless k == :records
        existing_item[1][k] = safely_combine_records(existing_item[1][k], v)
      end
    end

    def safely_combine_records old_requests, new_requests
      is_subset = -> (a, b) {
        (a[:attributes] & b[:attributes]) == b[:attributes] && (a[:ids] & b[:ids]) == b[:ids]
      }

      new_requests.each do |new_request|
        merged = false
        old_requests = old_requests.map do |old_request|
          next old_request if merged

          if new_request[:ids] == old_request[:ids]
            if new_request[:attributes] == old_request[:attributes]
              merged = true
            else
              old_request[:attributes] = (old_request[:attributes] + new_request[:attributes]).uniq
              merged = true
            end
          elsif new_request[:attributes] == old_request[:attributes]
            old_request[:ids] = (old_request[:ids] + new_request[:ids]).uniq
            merged = true
          elsif is_subset[old_request, new_request]
            merged = true
          elsif is_subset[new_request, old_request]
            old_request[:ids] = new_request[:ids]
            old_request[:attributes] = new_request[:attributes]
            merged = true
          end
          old_request
        end
        old_requests << new_request unless merged
      end

      old_requests
    end

    # Given input of { api: [dependent_apis], api_name: [dependent_apis] ... }
    # Returns [api, api] greedily ordered by constraint satisfaction

    def order_blobs hash
      graph = {}
      hash.map do |k, v|
        graph[k] ||= { incoming: [], outgoing: [] }
        graph[k][:outgoing] += v
        v.each do |outgoing|
          graph[outgoing] ||= { incoming: [], outgoing: [] }
          graph[outgoing][:incoming] << k
        end
      end

      next_node = -> {
        return nil unless graph.keys.any?
        k, v = graph.sort_by { |(_k, v)| [v[:outgoing].size, 0 - v[:incoming].size] }[0]
        v[:incoming].each { |incoming| graph[incoming][:outgoing] -= [k] }
        v[:outgoing].each { |outgoing| graph[outgoing][:incoming] -= [k] }
        graph.delete(k)
        k
      }

      i = graph.length
      list = Array.new(i)
      while (k = next_node.call)
        i -= 1
        list[i] = k
      end

      list
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

module Cord
  class ApiBaseController < ::ApplicationController
    include Helpers

    def respond
      data = {}
      Array.wrap(params[:_json]).each do |body|
        body = body.permit!.to_hash.with_indifferent_access
        api = load_api(body[:api])
        data[api] = body
      end
      render json: prepare_json(data)
    end

    def prepare_json data
      # dumb version for now

      data.map do |api, body|
        blob = { table: api.resource_name }
        ids = (body[:ids] || []).map { |x|
          [x[:_id], api.render_ids(x[:scopes], x[:query], x[:sort])]
        }.to_h
        ids.merge! ids.delete(nil) if ids[nil]
        blob[:ids] = ids
        blob[:records] = (body[:records] || []).map do |x|
          api.render_records x[:ids], x[:attributes]
        end
        blob[:actions] = (body[:actions] || []).map do |x|
          if x[:ids]
            result = api.perform_bulk_member_action(x[:ids], x[:name], x[:data])
          else
            result = api.perform_collection_action(x[:name], x[:data])
          end
          { _id: x[:_id], data: result }
        end
        blob
      end
    end

    def perform_actions *args

    end

    def load_ids api, *args

    end

    def load_records api, ids = [], attributes = []

      # for each attribute, try to find a macro, else try to find an attribute, else error
    end
  end
end


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

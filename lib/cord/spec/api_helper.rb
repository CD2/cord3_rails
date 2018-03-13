# Within a test group, define api_route, current_user and optionally headers:
#   let(:api_route) { '/v1' }
#   let(:current_user) { FactoryBot.create(:user) }
#   let(:headers) { {} }
#
# Then within a test, use your apis as follows:
#   api = api(:users)
#   ids = api.ids :all, search: 'query', sort: 'id desc'
#   records = api.records ids, attributes: [:email]
#   data1 = api.perform :a_member_action, data: { k: :v }, id: ids.first
#   data2 = api.perform :a_collection_action, data: { k: :v }

module Cord
  module Spec
    class ApiHelper
      def initialize name, kaller
        @caller = kaller
        @api = Cord::BaseApi.find_api(name)
      end

      attr_reader :api

      def records ids, attributes: []
        body = { ids: Array.wrap(ids), attributes: attributes }
        response = request [{ api: name, records: [body] }]
        response[:records]
      end

      def ids scope, search: nil, sort: nil
        request_id = SecureRandom.hex(3)
        body = { _id: request_id, scopes: [scope] }
        body[:query] = search if search
        body[:sort] = sort if sort
        response = request [{ api: name, ids: [body] }]
        response[:ids][request_id][scope]
      end

      def perform action_name, data: {}, id: nil
        request_id = SecureRandom.hex(3)
        body = { _id: request_id, name: action_name, data: data }
        body[:ids] = [id] if id
        response = request [{ api: name, actions: [body] }]
        response[:actions].detect { |x| x[:_id] = request_id }
      end

      def request body
        begin; h = @caller.headers; rescue NoMethodError; end
        h = (h || {}).merge('Content-Type' => 'application/json', 'Accept' => 'application/json')
        @caller.post(@caller.api_route, params: { _json: body }.to_json, headers: h)
        @caller.response_body.detect { |x| x[:table] == api.resource_name }
      end

      def name
        @api.name.chomp('Api').underscore
      end
    end
  end
end

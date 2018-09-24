# frozen_string_literal: true

module Cord
  # [
  #   :notFound,
  #   :validation,
  #   server: %i[badRequest noAction noApi noScope noId unhandled],
  # ]

  class BetaController < ApiBaseController
    before_action :preprocess_blobs

    def preprocess_blobs
      @blobs = Array.wrap(params[:_json])
      @blobs.each do |blob|
        blob[:data] ||= {}
        next if blob[:id]
        return render(
          status: :bad_request,
          json: { message: 'request contains blobs with no value for "id"' }
        )
      end
    end

    def respond
      render json: process_request(@blobs)
    end

    def process_request(request_blobs)
      response = Response.new request_blobs
      grouped_requests = request_blobs.group_by { |blob| normalize(blob[:type]) }

      Cord.handlers.each do |type, handler_class|
        next unless (blobs = grouped_requests.delete(type))
        process_blobs(response, handler_class, blobs)
      end

      grouped_requests.each do |type, blobs|
        response.respond_error(
          blobs,
          :server,
          type: :unhandled,
          message: "no handler for #{type.inspect}"
        )
      end

      response.finalize!
      response.to_json
    end

    def process_blobs(response, handler_class, blobs)
      handler = handler_class.new(self, response)
      handler.validate blobs
      handler.process response.unhandled_blobs(blobs)
    rescue => e
      response.respond_error response.unhandled_blobs(blobs), :server
      error_log(e)
    end

    def render_aliases(api, aliases)
      # TODO
    end
  end
end

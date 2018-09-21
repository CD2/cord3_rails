# frozen_string_literal: true

module Cord
  def self.log_error e
    str = [nil, e.message, *e.backtrace, nil].join("\n")
    respond_to?(:logger) ? logger.error(str) : puts(str)
  end

  class BetaController < ApiBaseController
    def respond
      render json: process_request(params[:_json])
    end

    def process_request(request_blobs)
      response = Response.new request_blobs

      grouped_requests = request_blobs.group_by { |blob| blob[:type] }
      grouped_requests.each do |request_type, blobs|
        handler_class = Cord.get_handler request_type
        next response.respond_error blobs, :no_handler unless handler_class

        handler = handler_class.new response
        begin
          handler.process blobs
        rescue => e
          response.respond_error response.unhandled_blobs(blobs), :server
          Cord.log_error e
        end
      end

      response.finialize!
      response.to_json
    end
  end

  # Resposne class holds the response data and automatically responds with unhandled blobs

  class Response
    @response = {}

    def initialize(blobs)
      @blobs = blobs
    end

    def respond_data(blobs, data)
      Array.wrap(blobs).each do |blob|
        respond blob, data: data
      end
    end

    def respond_error(blobs, name, data= nil)
      Array.wrap(blobs).each do |blob|
        respond blob, error: { type: name, data: data }
      end
    end

    def respond(blob, data)
      @response ||= {}
      raise IOError, :double_render if @response.key? blob[:id]
      @response[blob[:id]] = data
    end

    def responded_to? blob
      @response ||= {}
      @response.key? blob[:id]
    end

    def unhandled_blobs blobs = @blobs
      blobs.reject { |blob| responded_to? blob }
    end

    def finialize!
      respond_error unhandled_blobs, :not_handled
      freeze
    end

    def to_json
      @response.map { |key, value| { id: key, **value } }
    end
  end
end

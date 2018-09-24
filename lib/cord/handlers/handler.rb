# frozen_string_literal: true

module Cord
  def self.handlers
    @handlers ||= {}
  end

  def self.register_handler(name, handler)
    handlers[helpers.normalize(name)] = handler
  end

  class Handler
    include Helpers

    attr_accessor :controller
    attr_accessor :response

    def initialize(controller, response)
      self.controller = controller
      self.response = response
    end

    def process(blobs)
      blobs.each do |blob|
        process_each blob
      rescue => e
        error blob, :server
        error_log(e)
      end
    end

    def process_each(_blob)
      raise NotImplementedError, "#{self.class} does not implement process_each"
    end

    def validate(blobs)
      blobs.each { |blob| validate_each(blob) }
    end

    def validate_each(_blob); end

    def render(blob, data)
      response.respond_data blob, data
    end

    def error(blob, name, data = nil)
      response.respond_error blob, name, data
    end
  end
end

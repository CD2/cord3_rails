# frozen_string_literal: true

module Cord
  def self.register_handler(name, handler)
    @handlers ||= {}
    @handlers[name] = handler
    @handlers[name.to_s] = handler
  end

  def self.get_handler(name)
    @handlers ||= {}
    @handlers[name]
  end

  # base handler class gives simple helper methods. Based off of the validation classes from ruby
  class Handler
    def initialize(response)
      @response = response
    end

    def process(blobs)
      blobs.each do |blob|
        process_each blob
      rescue => e
        error blob, :server
        Cord.log_error e
      end
    end

    def process_each(_blob)
      raise IOError, 'must implement process_each'
    end

    def render(blob, data)
      @response.respond_data blob, data
    end

    def error(blob, name, data=nil)
      @response.respond_error blob, name, data
    end
  end
end

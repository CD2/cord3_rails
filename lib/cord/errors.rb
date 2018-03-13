module Cord
  StandardError = Class.new(::StandardError)

  AbstractApiError = Class.new(StandardError)

  class RecordNotFound < StandardError
    def initialize *ids
      super "could not find record for ids: #{ids.flatten}"
    end
  end
end

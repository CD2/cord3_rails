module Cord
  StandardError = Class.new(::StandardError)

  AbstractApiError = Class.new(StandardError)

  class RecordNotFound < StandardError
    def initialize *ids
      super "could not find record for ids: #{ids.map { |x| x.is_a?(Set) ? x.to_a : x }.flatten}"
    end
  end
end

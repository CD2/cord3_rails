module Cord
  class Parameters < ::ActionController::Parameters
    attr_reader :rejected_parameters
    attr_accessor :api

    def unpermitted_parameters! params
      unpermitted_keys = unpermitted_keys(params)
      return if unpermitted_keys.none?
      str = "Unpermitted parameters: #{unpermitted_keys}"

      case Cord.action_on_unpermitted_parameters
      when :warn
        api ? api.send(:warning, str) : puts(str)
      when :error
        e = UnpermittedParameters.new(str)
        api ? api.send(:error, e) : raise(UnpermittedParameters, e)
      end

      @rejected_parameters = unpermitted_keys(params)
    end

    def to_a
      to_h.to_a
    end

    def size
      keys.size
    end

    alias count size
    alias length size

    def only *args
      prev = Cord.action_on_unpermitted_parameters
      Cord.action_on_unpermitted_parameters = nil
      result = permit(*args)
      Cord.action_on_unpermitted_parameters = prev
      result
  end
end

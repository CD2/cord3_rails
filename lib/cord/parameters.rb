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
  end
end

module Cord
  module DSL
    module Actions
      extend ActiveSupport::Concern

      private

      def perform_action(name, data, errors: [])
        name = normalize(name)
        @data = ActionController::Parameters.new(data) if data
        @response = {}
        @errors = errors
        if @record
          action = member_actions[name]
          raise ArgumentError, "undefined member action: '#{name}'" unless action
          instance_exec(@record, &action)
        else
          action = collection_actions[name]
          raise ArgumentError, "undefined collection action: '#{name}'" unless action
          instance_exec &action
        end
        result = @response
        @data, @response, @errors = nil
        result
      end

      attr_reader :data

      def render data
        raise 'Call to \'render\' after action chain has been halted' if @halted
        @response.merge! data
      end

      def error data
        @errors << data
      end

      def halt! message = nil
        return if halted?
        @response = nil
        error message if message
        @halted = true
      end

      def halted?
        !!@halted
      end
    end
  end
end

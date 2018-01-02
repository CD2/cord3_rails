module Cord
  module DSL
    module Actions
      extend ActiveSupport::Concern

      private

      def perform_action(name, data)
        name = normalize(name)
        @data = ActionController::Parameters.new(data) if data
        @response = {}
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
        @data, @response = nil
        result
      end

      attr_reader :data

      def render data
        raise 'Call to \'render\' after action chain has been halted' if @halted
        @response.merge! data
      end

      def halt! message = nil, status: 401
        return if halted?
        if message
          @response = {}
          error message
        else
          @response = nil
        end
        @halted = true
      end

      def halted?
        !!@halted
      end
    end
  end
end

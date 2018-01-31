module Cord
  module DSL
    module Actions
      extend ActiveSupport::Concern

      included do
        hash_stores %i[member_actions collection_actions]

        class << self
          def action name, &block
            if context.member?
              member_actions.add(name, &block)
            else
              collection_actions.add(name, &block)
            end
          end

          def collection_action name, &block
            collection_actions.add(name, &block)
          end

          def member_action name, &block
            member_actions.add(name, &block)
          end
        end
      end

      def perform_bulk_member_action ids, name, data = {}, errors: []
        @actions_json = []
        records = driver.where(id: ids)
        records.each do |record|
          @actions_json << perform_member_action(record, name, data, errors: errors)
        end
        @actions_json
      end

      def perform_member_action record, name, data = {}, errors: []
        temp_record = @record
        @record = record
        result = perform_action(name, data, errors: errors)
        @record = temp_record
        result
      end

      def perform_collection_action name, data = {}, errors: []
        temp_record = @record
        @record = nil
        result = perform_action(name, data, errors: errors)
        @record = temp_record
        result
      end

      private

      def perform_action(name, data, errors: [])
        name = normalize(name)
        @data = ActionController::Parameters.new(data) if data
        @response = {}
        @errors = errors
        @halted = false
        if @record
          action = member_actions[name]
          raise ArgumentError, "undefined member action: '#{name}'" unless action
          perform_before_actions(name)
          instance_exec(@record, &action) unless halted?
        else
          action = collection_actions[name]
          raise ArgumentError, "undefined collection action: '#{name}'" unless action
          perform_before_actions(name)
          instance_exec(&action) unless halted?
        end
        result = @response
        @data, @response, @errors, @halted = nil
        result
      end

      def perform_before_actions name
        name = normalize(name)
        before_actions.values.each do |before_action|
          next unless (before_action[:only] && before_action[:only].include?(name)) ||
          (before_action[:except] && !before_action[:except].include?(name))
          instance_eval &before_action[:block]
          break if halted?
        end
      end

      attr_reader :data

      def render data
        return error('call to \'render\' after action has been halted') if halted?
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

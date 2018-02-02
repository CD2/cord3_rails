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

      def perform_bulk_member_action(
        ids, name,
        data: {}, errors: nil, before_actions: false, nested: true
      )
        @actions_json = []
        records = driver.where(id: ids)
        records.each do |record|
          @actions_json << perform_member_action(
            record, name, data: data, errors: errors, before_actions: before_actions, nested: nested
          )
        end
        @actions_json
      end

      def perform_member_action(
        record, name,
        data: nil, errors: nil, before_actions: false, nested: true
      )
        data ||= {}

        temp_record = @record
        @record = record
        result = perform_action(
          name, data: data, errors: errors, before_actions: before_actions, nested: nested
        )
        @record = temp_record
        result
      end

      def perform_collection_action(
        name,
        data: nil, errors: nil, before_actions: false, nested: true
      )
        data ||= {}

        temp_record = @record
        @record = nil
        result = perform_action(
          name, data: data, errors: errors, before_actions: before_actions, nested: nested
        )
        @record = temp_record
        result
      end

      private

      def perform_action(name, data: nil, errors: nil, before_actions: false, nested: true)
        data ||= {}
        name = normalize(name)

        temp_response = @response
        temp_data = @data

        unless nested
          @errors = errors || []
          @halted = false
        end

        @data = ActionController::Parameters.new(data)
        @response = {}

        if @record
          action = member_actions[name]
          raise ArgumentError, "undefined member action: '#{name}'" unless action
          perform_before_actions(name) if before_actions
          instance_exec(@record, &action) unless halted?
        else
          action = collection_actions[name]
          raise ArgumentError, "undefined collection action: '#{name}'" unless action
          perform_before_actions(name) if before_actions
          instance_exec(&action) unless halted?
        end

        result = @response
        @errors, @halted = nil unless nested
        @response = temp_response unless halted?
        @data = temp_data
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
        @errors ||= []
        @errors << data
      end

      def halt! message = nil
        return if halted?
        @response = {}
        error message if message
        @halted = true
      end

      def halted?
        !!@halted
      end
    end
  end
end

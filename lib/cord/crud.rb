module Cord
  module CRUD
    extend ActiveSupport::Concern

    included do
      def self.crud_actions *actions
        actions.map!(&:to_sym)
        define_create if actions.delete :create
        define_update if actions.delete :update
        define_destroy if actions.delete :destroy
        raise "Unknown actions: #{actions.joins(', ')}" if actions.any?
      end

      def self.define_create
        collection do
          action :create do
            resource = driver.new(resource_params)
            instance_exec resource, &crud_callbacks[:before_create]
            next if halted?
            if raise_on_crud_error?
              resource.save!
              render(id: resource.id)
            else
              resource.save ? render(id: resource.id) : render(resource.errors)
            end
            instance_exec resource, &crud_callbacks[:after_create]
          end
        end
      end

      def self.define_update
        action :update do |resource|
          instance_exec resource, &crud_callbacks[:before_update]
          next if halted?
          if raise_on_crud_error?
            resource.update!(resource_params)
            render(id: resource.id)
          else
            if resource.update(resource_params)
              render(id: resource.id)
            else
              render resource.errors
            end
          end
          instance_exec resource, &crud_callbacks[:after_update]
        end
      end

      def self.define_destroy
        action :destroy do |resource|
          instance_exec resource, &crud_callbacks[:before_destroy]
          next if halted?
          resource.destroy
          crud_callbacks[:after_destroy].call(resource)
        end
      end

      CRUD_CALLBACKS = %i[
        before_create after_create before_update after_update before_destroy after_destroy
      ]

      def self.crud_callbacks
        @crud_callbacks ||= CRUD_CALLBACKS.map { |x| [x, proc { |resource| }]}.to_h
      end

      CRUD_CALLBACKS.each do |callback|
        eval <<-RUBY
        def self.#{callback} name = nil, &block
          raise ArgumentError, 'Must provide either a block or a method name' unless name || block
          name = name.to_sym if name
          block ||= ->(resource){
            case method(name).arity
            when 0
              send(name)
            when 1
              send(name, resource)
            else
              raise ArgumentError, 'Method "' + name.to_s + '" takes unexpected input, use a block'
            end
          }
          crud_callbacks[:#{callback}] = block
        end
        RUBY
      end

      def self.permitted_params
        @permitted_params ||= []
      end

      def self.permitted_params= arg
        @permitted_params = arg
      end

      def self.permit_params *args
        args = Array.wrap(args[0]) if args.one?
        @permitted_params ||= []
        @permitted_params += args
      end

      def self.raise_on_crud_error?
        return @raise_on_crud_error unless @raise_on_crud_error.nil?
        @raise_on_crud_error = Cord.raise_on_crud_error
      end

      def self.raise_on_crud_error value
        @raise_on_crud_error = value
      end
    end

    def resource_params
      return {} if data[resource_name.singularize]&.blank?
      data.require(resource_name.singularize).permit(permitted_params)
    end

    def permitted_params
      self.class.permitted_params
    end

    def crud_callbacks
      self.class.crud_callbacks
    end

    def raise_on_crud_error?
      self.class.raise_on_crud_error?
    end
  end
end

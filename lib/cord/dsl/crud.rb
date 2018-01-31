module Cord
  module DSL
    module CRUD
      extend ActiveSupport::Concern

      included do
        hash_stores :crud_callbacks
        array_stores :permitted_params

        def self.crud_actions *actions
          actions = actions.flatten.map(&:to_sym)
          define_create if actions.delete :create
          define_update if actions.delete :update
          define_destroy if actions.delete :destroy
          raise ArgumentError, "unknown actions: #{actions.joins(', ')}" if actions.any?
        end

        def self.define_create
          collection do
            action :create do
              resource = driver.new(resource_params)
              instance_exec resource, &crud_callbacks['before_create']
              next if halted?
              instance_exec resource, &crud_callbacks['before_save']
              next if halted?
              if resource.save
                render(id: resource.id)
                instance_exec resource, &crud_callbacks['after_save']
                instance_exec resource, &crud_callbacks['after_create']
              else
                error(resource.errors.as_json)
              end
            end
          end
        end

        def self.define_update
          action :update do |resource|
            resource.assign_attributes(resource_params)
            instance_exec resource, &crud_callbacks['before_update']
            next if halted?
            instance_exec resource, &crud_callbacks['before_save']
            next if halted?
            if resource.save
              render(id: resource.id)
              instance_exec resource, &crud_callbacks['after_save']
              instance_exec resource, &crud_callbacks['after_update']
            else
              error resource.errors.as_json
            end
          end
        end

        def self.define_destroy
          action :destroy do |resource|
            instance_exec resource, &crud_callbacks['before_destroy']
            next if halted?
            resource.destroy
            crud_callbacks['after_destroy'].call(resource)
          end
        end

        CRUD_CALLBACKS = %i[
          before_create after_create before_update after_update before_destroy after_destroy
          before_save after_save
        ]

        CRUD_CALLBACKS.each do |callback|
          eval <<-RUBY
          def self.#{callback} name = nil, &block
            raise ArgumentError, 'must provide either a block or a method name' unless name || block
            block ||= -> (resource) {
              case method(name).arity
              when 0
                send(name)
              when 1
                send(name, resource)
              else
                raise ArgumentError, 'method "\#{name}" takes unexpected input, use a block'
              end
            }
            crud_callbacks['#{callback}'] = block
          end
          RUBY
        end

        def self.permit_params *args
          permitted_params.add *args
        end
      end

      def resource_params
        data.permit(permitted_params)
      end
    end
  end
end

module Cord
  module DSL
    module CRUD
      extend ActiveSupport::Concern

      included do
        hash_stores :crud_callbacks
        # array_stores :permitted_params

        def self.permitted_params *values
          unless @permitted_params
            @permitted_params = self == ::Cord::BaseApi ? [] : superclass.permitted_params.deep_dup

            def @permitted_params.add *names
              replace(self | names.flatten)
            end

            def @permitted_params.remove *names
              replace(self - names.flatten)
            end
          end

          @permitted_params.add values

          @permitted_params
        end

        def self.permitted_params= value
          permitted_params.replace(value)
        end

        def permitted_params
          self.class.permitted_params
        end

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
              resource = driver.new(resource_params.merge(id: nil))
              run_crud_callbacks(:before_create, resource)
              next if halted?
              run_crud_callbacks(:before_save, resource)
              next if halted?
              if resource.save
                render(id: resource.id)
                run_crud_callbacks(:after_save, resource)
                next if halted?
                run_crud_callbacks(:after_create, resource)
              else
                error(resource.errors.as_json.as_json)
              end
            end
          end
        end

        def self.define_update
          action :update do |resource|
            resource.with_lock do
              resource.assign_attributes(resource_params)
              run_crud_callbacks(:before_modify, resource)
              next if halted?
              run_crud_callbacks(:before_update, resource)
              next if halted?
              run_crud_callbacks(:before_save, resource)
              next if halted?
              if resource.save
                render(id: resource.id)
                run_crud_callbacks(:after_save, resource)
                next if halted?
                run_crud_callbacks(:after_update, resource)
                next if halted?
                run_crud_callbacks(:after_modify, resource)
              else
                error resource.errors.as_json.as_json
              end
            end
          end
        end

        def self.define_destroy
          action :destroy do |resource|
            run_crud_callbacks(:before_modify, resource)
            next if halted?
            run_crud_callbacks(:before_destroy, resource)
            next if halted?
            resource.destroy
            run_crud_callbacks(:after_destroy, resource)
            next if halted?
            run_crud_callbacks(:after_modify, resource)
          end
        end

        CRUD_CALLBACKS = %i[
          before_create after_create before_update after_update before_destroy after_destroy
          before_save after_save before_modify after_modify
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
            crud_callbacks[:#{callback}] << block
          end
          RUBY
        end

        def self.permit_params *args
          permitted_params.add(*args)
        end

        def run_crud_callbacks key, resource
          crud_callbacks[key].each do |callback|
            instance_exec resource, &callback
            return if halted?
          end
        end
      end

      def resource_params
        data.permit(permitted_params)
      end
    end
  end
end

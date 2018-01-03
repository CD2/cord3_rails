module Cord
  module Helpers
    extend ActiveSupport::Concern

    included do
      undelegated_methods = methods

      class << self
        def is_api? obj
          obj.is_a?(Class) && obj < Cord::BaseApi
        end

        def find_api_name value
          # if is_api?(self) && model&.reflect_on_association(value)
          # fill in class based on type of association
          value.to_s.camelcase.chomp('Api').pluralize + 'Api'
        end

        def find_api value, namespace: nil
          api_name = find_api_name(value)
          namespaced_api_name = namespace ? "#{namespace}::#{api_name}" : api_name
          begin
            api = namespaced_api_name.constantize
          rescue NameError => e
            namespace ||= name
            next_namespace = namespace.deconstantize
            if next_namespace.present?
              api = find_api(api_name, namespace: next_namespace)
            else
              raise e
            end
          end
          raise NameError, "#{api} is not a Cord Api" unless is_api?(api)
          api
        end

        def is_model? obj
          obj.is_a?(Class) && obj < ActiveRecord::Base
        end

        def is_driver? obj
          obj.is_a?(ActiveRecord::Relation)
        end

        def normalize str
          str.to_s.downcase
        end

        def apply_scope driver, name, scope
          raise ArgumentError, 'expected an ActiveRecord::Relation' unless is_driver?(driver)
          result = instance_exec(driver, &scope)
          unless is_driver?(result)
            raise ArgumentError, "scope '#{name}' did not return an ActiveRecord::Relation"
          end
          result
        end

        def apply_sort(driver, sort)
          raise ArgumentError, 'expected an ActiveRecord::Relation' unless is_driver?(driver)
          col, dir = sort.downcase.split(' ')
          unless dir.in?(%w[asc desc])
            error "sort direction must be either 'asc' or 'desc', instead got '#{dir}'"
            return driver
          end
          if col.in?(model.column_names)
            driver.order(col => dir)
          else
            error "unknown sort #{col}"
            driver
          end
        end

        def apply_search(driver, search, columns = [])
          raise ArgumentError, 'expected an ActiveRecord::Relation' unless is_driver?(driver)
          condition = columns.map { |col| "#{col} ILIKE :term" }.join ' OR '
          driver.where(condition, term: "%#{search}%")
        end
      end

      delegate *(methods - undelegated_methods), to: :class

      def self.load_api value
        api = value if is_api?(value)
        api ||= find_api(value)
        api.new
      end

      def load_api value
        api = value if is_api?(value)
        api ||= find_api(value)

        controller_instance = controller if is_api?(self)
        controller_instance = self if is_a?(ApiBaseController)

        api.new(controller_instance)
      end
    end
  end
end

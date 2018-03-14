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
          if is_api?(self) && (reflection = model&.reflect_on_association(value))
            value = reflection.class_name
          end
          value.to_s.underscore.camelcase.chomp('Api').pluralize + 'Api'
        end

        def find_api value, namespace: nil
          api_name = find_api_name(value)
          namespaced_api_name = namespace ? "#{namespace}::#{api_name}" : api_name
          begin
            api = namespaced_api_name.constantize
          rescue NameError => e
            case e.message
            when /uninitialized constant #{namespaced_api_name}/
              namespace ||= name
              next_namespace = namespace.deconstantize
              if next_namespace.present?
                api = find_api(api_name, namespace: next_namespace)
              else
                raise e
              end
            else
              raise e
            end
          end
          raise NameError, "#{api} is not a Cord Api" unless is_api?(api)
          api
        end

        def strict_find_api value
          api_name = value.camelcase + 'Api'
          begin
            api = api_name.constantize
          rescue NameError => e
            case e.message
            when /uninitialized constant #{api_name}/, /wrong constant name #{api_name}/
              raise NameError, "api name '#{value}' was not matched (#{e})"
            else
              raise e
            end
          end
          raise NameError, "#{api} is not a Cord Api" unless is_api?(api)
          api
        end

        def error_log e
          e = StandardError.new(e) unless e.is_a?(Exception)
          raise e if Rails.env.development? && e.is_a?(SystemExit)
          case Cord.action_on_error
          when :log
            str = [nil, e.message, *e.backtrace, nil].join("\n")
            respond_to?(:logger) ? logger.error(str) : puts(str)
          when :raise
            raise e
          end
        end

        def model_from_api api = self
          name = (api.is_a?(String) ? api : api.name).chomp('Api').singularize
          begin
            name.constantize
          rescue NameError => e
            case e.message
            when /uninitialized constant #{name}/
              next_name = name.split('::')[1..-1].join('::')
              if next_name.present?
                model_from_api(next_name)
              else
                raise e
              end
            else
              raise e
            end
          end
        end

        def is_record? obj
          is_model?(obj.class)
        end

        def is_model? obj
          obj.is_a?(Class) && obj < ::ActiveRecord::Base
        end

        def is_driver? obj
          obj.is_a?(::ActiveRecord::Relation)
        end

        def assert_driver obj
          return if is_driver?(obj)
          raise ArgumentError, "expected an ActiveRecord::Relation, instead got #{obj.class}"
        end

        def normalize s
          s.to_s.downcase
        end

        def normalize_hash h
          h.map { |k, v| [normalize(k), v] }.to_h
        end

        def normalize_array a
          a.map { |x| normalize x }
        end

        def driver_to_json driver
          assert_driver(driver)

          return JSONString.new('[]') if driver.to_sql.blank?

          response = ::ActiveRecord::Base.connection.execute <<-SQL.squish
            SELECT
              array_to_json(array_agg(json))
            FROM
              (#{driver.to_sql}) AS json
          SQL

          JSONString.new(response.values.first.first || '[]')
        end

        def driver_to_json_with_missing_ids driver, ids
          assert_driver(driver)

          return [JSONString.new('[]'), ids] if driver.to_sql.blank?

          response = ::ActiveRecord::Base.connection.execute <<-SQL.squish
            SELECT
              array_to_json(array_agg(json)),
              array_agg(json.id)
            FROM
              (#{driver.to_sql}) AS json
          SQL

          json = JSONString.new(response.values.first.first || '[]')

          if found_ids = response.values.first.last
            ids -= (found_ids[1...-1].split(','))
          end

          [json, ids]
        end

        def json_merge x, y
          return x + y if x.is_a?(Array)
          return x.merge(y) { |_k, v1, v2| json_merge(v1, v2) } if x.is_a?(Hash)
          y
        end

        def json_stringify x
          return x.map { |v| json_stringify(v) } if x.is_a?(Array)
          return x.map { |k, v| [k.to_s, json_stringify(v)] }.to_h if x.is_a?(Hash)
          x.is_a?(Symbol) ? x.to_s : x
        end

        def json_symbolize x
          return x.map { |v| json_symbolize(v) } if x.is_a?(Array)
          return x.map { |k, v| [k.to_s.to_sym, json_symbolize(v)] }.to_h if x.is_a?(Hash)
          x
        end

        def json_inspect x, options = {}
          indent_level = options.fetch(:indent_level, 0)
          indent_str = options.fetch(:indent_str, '  ')
          indent_first = options.fetch(:indent_first, true)
          max_width = options.fetch(:max_width, nil) || `tput cols`.to_i
          max_width_first = options.fetch(:max_width_first, max_width)
          flat = options.fetch(:flat, false)

          indent = indent_str * indent_level

          flat_render = -> (x) {
            json_inspect(x, indent_str: indent_str, max_width: max_width, flat: true)
          }

          array_nest_render = -> (x) {
            json_inspect(
              x,
              indent_level: indent_level + 1,
              indent_str: indent_str,
              max_width: max_width - indent_str.size,
            )
          }

          hash_nest_render = -> (x, n) {
            json_inspect(
              x,
              indent_level: indent_level + 1,
              indent_str: indent_str,
              max_width: max_width - indent_str.size,
              max_width_first: max_width - n,
              indent_first: false
            )
          }

          if x.is_a?(Hash)
            inner = x.map do |k, v|
              k.is_a?(Symbol) ? "#{k}: #{flat_render[v]}" : "#{k.inspect} => #{flat_render[v]}"
            end
            str = "#{indent_first ? indent : nil}{ #{inner.join(', ')} }"

            return str unless !flat && (str.size > max_width_first || str.include?("\n"))

            return [
              "#{indent_first ? indent : nil}{",
              *x.map do |k, v|
                key_str = if k.is_a?(Symbol)
                  "#{indent}#{indent_str}#{k}: "
                else
                  "#{indent}#{indent_str}#{k.inspect} => "
                end
                str = key_str + flat_render[v] + ','
                next str unless str.size > max_width
                key_str + hash_nest_render[v, key_str.size + 1] + ','
              end,
              "#{indent}}"
            ].join("\n")
          end

          if x.is_a?(Array)
            inner = x.map { |v| flat_render[v] }
            str = "#{indent_first ? indent : nil}[#{inner.join(', ')}]"

            return str unless !flat && (str.size > max_width_first || str.include?("\n"))

            return [
              "#{indent_first ? indent : nil}[",
              *x.map { |v| "#{array_nest_render[v]}," },
              "#{indent}]"
            ].join("\n")
          end

          indent + x.inspect
        end
      end

      delegate *(methods - undelegated_methods), to: :class

      def self.assert_not_abstract api = self
        raise AbstractApiError, "#{api.name} is abstract" if api.abstract?
      end

      def assert_not_abstract api = self.class
        raise AbstractApiError, "#{api.name} is abstract" if api.abstract?
      end

      def self.apply_scope driver, name, scope
        assert_driver(driver)
        result = instance_exec(driver, &scope)
        unless is_driver?(result)
          raise ArgumentError, "scope '#{name}' did not return an ActiveRecord::Relation"
        end
        result
      end

      def apply_scope driver, name, scope
        assert_driver(driver)
        result = instance_exec(driver, &scope)
        unless is_driver?(result)
          raise ArgumentError, "scope '#{name}' did not return an ActiveRecord::Relation"
        end
        result
      end

      def self.load_api value
        api = value if is_api?(value)
        api ||= find_api(value)
        api.new
      end

      def load_api value
        api = value if is_api?(value)
        api ||= find_api(value)

        controller_instance = controller if is_api?(self.class)
        controller_instance = self if is_a?(ApiBaseController)

        api.new(controller_instance)
      end
    end
  end
end

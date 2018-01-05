module Cord
  module DSL
    module Keywords
      extend ActiveSupport::Concern

      private

      def requested? keyword
        keyword = normalize(keyword)
        @keywords.include? keyword
      end

      def render_attribute name
        name = normalize(name)
        @record_json[name] = get_attribute(name)
      end

      def get_attribute name
        name = normalize(name)
        if @calculated_attributes.has_key?(name)
          @calculated_attributes[name]
        else
          calculate_attribute(name)
        end
      end

      def calculate_attribute(name)
        name = normalize(name)
        raise ArgumentError, "undefined attribute: '#{name}'" unless attributes[name]
        begin
          @calculated_attributes[name] = instance_exec(@record, &attributes[name])
        rescue Exception => e
          error_log e
          @record_json[:_errors] << e
          nil
        end
      end

      def perform_macro(name, *args)
        name = normalize(name)
        raise ArgumentError, "undefined macro: '#{name}'" unless macros[name]
        begin
          instance_exec(*args, &macros[name])
        rescue Exception => e
          error_log e
          @record_json[:_errors] << e
        end
      end

      def keyword_missing name
        @record_json[:_errors] << "'#{name}' does not match any keywords defined for #{self.class}"
      end
    end
  end
end

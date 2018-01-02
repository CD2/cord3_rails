module Cord
  module DSL
    module Records
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
        @calculated_attributes[name] = instance_exec(@record, &attributes[name])
      end

      def perform_macro(name, *args)
        name = normalize(name)
        raise ArgumentError, "undefined macro: '#{name}'" unless macros[name]
        instance_exec(*args, &macros[name])
      end

      def keyword_missing name
        raise NameError, "'#{name}' does not match any keywords defined for #{self.class.name}"
      end
    end
  end
end

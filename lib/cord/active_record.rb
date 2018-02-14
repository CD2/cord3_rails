require 'active_record'

module Cord
  module ActiveRecord
    def cord_file_accessors
      @cord_file_accessors ||= []
    end

    def cord_file_accessor name, *args, &block
      dragonfly_accessor name, *args, &block

      method_name = "#{name}="
      met = self.instance_method(method_name)
      define_method method_name do |val|
        if val.is_a?(Hash)
          val = val.symbolize_keys
          match_elements = -> (a, b) { a & b == a }
          if match_elements[val.keys, %i[data name]]
            self.send("#{name}_url=", val[:data])
            self.send("#{name}_name=", val[:name])
            return
          end
        end
        met.bind(self).call(val)
      end
      cord_file_accessors << name
    end

  end
end

ActiveRecord::Base.extend Cord::ActiveRecord

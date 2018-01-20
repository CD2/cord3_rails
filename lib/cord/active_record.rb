require 'active_record'

module Cord
  module ActiveRecord

    def cord_file_accessor name, *args, &block
      dragonfly_accessor name, *args, &block

      method_name = "#{name}="
      met = self.instance_method(method_name)
      define_method method_name do |val|
        if val.is_a?(Hash) && val.length === 2 && (val.keys - ['data', 'name']).length === 0
          self.send("#{name}_url=", val[:data])
          self.send("#{name}_name=", val[:name])
        else
          met.bind(self).call(val)
        end
      end
    end

  end
end

ActiveRecord::Base.extend Cord::ActiveRecord

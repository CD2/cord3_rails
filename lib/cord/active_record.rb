require 'active_record'
require_relative 'attachment'

module Cord
  module ActiveRecord
    module Base
      def cord_file_accessors
        return @cord_file_accessors if @cord_file_accessors
        if self == ::ActiveRecord::Base
          @cord_file_accessors = []
        else
          @cord_file_accessors = superclass.cord_file_accessors.deep_dup
        end
      end

      def cord_image_sizes
        return @cord_image_sizes if @cord_image_sizes
        if self == ::ActiveRecord::Base
          @cord_image_sizes = Hash.new { |h, k| h[k] = Cord.default_image_sizes.deep_dup }
        else
          @cord_image_sizes = superclass.cord_image_sizes.deep_dup
        end
        cord_file_accessors.each { |f| @cord_image_sizes[f] }
        @cord_image_sizes
      end

      def cord_file_accessor name, *args, &block
        name = Cord::BaseApi.normalize name

        dragonfly_accessor name, *args, &block

        method_name = "#{name}="
        met = instance_method(method_name)
        define_method method_name do |val|
          if val.is_a?(Hash)
            val = val.symbolize_keys
            match_elements = -> (a, b) { a & b == a }
            if match_elements[val.keys, %i[data name]]
              send("#{name}_url=", val[:data])
              send("#{name}_name=", val[:name])
              return
            end
          end
          met.bind(self).call(val)
        end

        define_method name do
          send("#{name}_uid") && Cord::Attachment.new(name, self)
        end

        if column_names.include? "#{name}_cache"
          define_method "reload_#{name}_cache" do
            update!("#{name}_cache" => send(name)&.reload_cache || {})
          end

          before_save do
            if send "#{name}_uid_changed?"
              new_cache = send("#{name}_uid") ? send(name)&.reload_cache || {} : {}
              self["#{name}_cache"] = new_cache
            end
          end

          before_destroy { send(name)&.destroy_cached_images }
        end

        cord_file_accessors << name
      end
    end

    module Migration
      def json_type_constraint table, column, type
        reversible do |dir|
          dir.up do
            columns = ::ActiveRecord::Base.connection.columns(table)
            json = (columns.detect { |x| x.name == column.to_s }&.type == :jsonb) ? :jsonb : :json
            execute <<-SQL.squish
              ALTER TABLE #{table}
              ADD CONSTRAINT #{table}_#{column}_is_#{type}
              CHECK (#{json}_typeof(#{column}) = '#{type}')
            SQL
          end
          dir.down do
            execute <<-SQL.squish
              ALTER TABLE #{table}
              DROP CONSTRAINT #{table}_#{column}_is_#{type}
            SQL
          end
        end
      end
    end
  end
end

::ActiveRecord::Base.extend Cord::ActiveRecord::Base
::ActiveRecord::Migration.include Cord::ActiveRecord::Migration

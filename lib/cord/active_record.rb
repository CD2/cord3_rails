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

      def cord_file_accessor name, *args
        name = Cord::BaseApi.normalize name

        dragonfly_accessor name, *args do
          after_assign do |attachment|
            attachment.convert!('-auto-orient') if attachment.ext != 'pdf' && attachment.image?
          end
        end

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
          ActiveSupport::Deprecation.silence { met.bind(self).call(val) }
        end

        define_method name do
          send("#{name}_uid") && Cord::Attachment.new(name, self)
        end

        if table_exists? && column_names.include?("#{name}_cache")
          define_method "reload_#{name}_cache" do
            update!("#{name}_cache" => send(name)&.reload_cache || {})
          end

          before_save do
            if send "will_save_change_to_#{name}_uid?"
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
      def cord_cache table
        add_column table, :cord_cache, :jsonb, default: {}, null: false
        json_type_constraint table, :cord_cache, :object
        add_index table, :cord_cache, using: :gin
      end

      def cord_file table, name = :file
        add_column table, "#{name}_uid", :string
        add_column table, "#{name}_name", :string
      end

      def cord_image table, name = :image
        cord_file table, name
        add_column table, "#{name}_cache", :jsonb, default: {}, null: false
        json_type_constraint table, "#{name}_cache", :object
      end

      def json_type_constraint table, column, type
        columns = get_connection.columns(table)
        json = (columns.detect { |x| x.name == column.to_s }&.type == :jsonb) ? :jsonb : :json
        check_constraint table, "#{json}_typeof(#{column}) = '#{type}'", "#{table}_#{column}_is_#{type}"
      end

      def check_constraint table, condition, name
        reversible do |dir|
          dir.up do
            execute <<-SQL.squish
              ALTER TABLE #{table}
              ADD CONSTRAINT #{name}
              CHECK (#{condition})
            SQL
          end
          dir.down do
            execute <<-SQL.squish
              ALTER TABLE #{table}
              DROP CONSTRAINT #{name}
            SQL
          end
        end
      end

      def set_connection new_connection
        case connection
        when ::ActiveRecord::ConnectionAdapters::AbstractAdapter
          @connection = new_connection
        when ::ActiveRecord::Migration::CommandRecorder
          connection.instance_variable_set(:@delegate, new_connection)
        else
          raise NotImplementedError, "Unexpected class for connection: #{connection.class}"
        end
      end

      def get_connection
        case connection
        when ::ActiveRecord::ConnectionAdapters::AbstractAdapter
          connection
        when ::ActiveRecord::Migration::CommandRecorder
          connection.instance_variable_get(:@delegate)
        else
          raise NotImplementedError, "Unexpected class for connection: #{connection.class}"
        end
      end
    end

    module ConnectionAdapters
      module TableDefinition
        def cord_cache
          jsonb :cord_cache, default: {}, null: false
          json_type_constraint :cord_cache, :object
          index :cord_cache, using: :gin
        end

        def cord_file name = :file
          string "#{name}_uid"
          string "#{name}_name"
        end

        def cord_image name = :image
          cord_file name
          jsonb "#{name}_cache", default: {}, null: false
          json_type_constraint "#{name}_cache", :object
        end

        def json_type_constraint name, type
          # TODO
          # Store the pair in a list somewhere then run through them after create
        end

        def check_constraint condition, name
          # TODO
          # Store the pair in a list somewhere then run through them after create
        end
      end
    end
  end
end

::ActiveRecord::Base.extend Cord::ActiveRecord::Base
::ActiveRecord::Migration.include Cord::ActiveRecord::Migration
::ActiveRecord::ConnectionAdapters::TableDefinition.include Cord::ActiveRecord::ConnectionAdapters::TableDefinition

# TODO: Refactor this whole file
::ActiveRecord::Base.instance_eval do
  def self.first_id
    all.order_values.empty? ? order(:id).limit(1).ids[0] : limit(1).ids[0]
  end
end

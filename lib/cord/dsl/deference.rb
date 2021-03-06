module Cord
  module DSL
    module Deference
      extend ActiveSupport::Concern

      included do
        class << self
          def defer *names, to:, fallback: false, prefix: false
            to = normalize(to)
            association = defined_associations.fetch(to, {})

            case association[:type]
            when :has_many
              raise ArgumentError, "cannot defer attributes to the has_many association '#{to}'"
            when :has_one, :belongs_to
              names.each do |name|
                defer_single normalize(name), association, fallback: fallback, prefix: prefix
              end
            when :virtual
              raise ArgumentError, "cannot defer attributes to the virtual association '#{to}'"
            when nil
              raise ArgumentError, "no association '#{to}' has been defined"
            end
          end

          def defer_single name, association, fallback:, prefix:
            local_name = prefix ? "#{association[:name]}_#{name}" : name

            self.attribute(local_name) if fallback && !self.attributes[local_name]
            local_attr = self.attributes[local_name]
            local_meta_attr = (meta_attributes[local_name].deep_dup || {})

            foreign_api = find_api(association[:api])

            unless foreign_api.attributes[name]
              raise(
                ArgumentError,
                "tried to defer '#{name}' to #{foreign_api}, but no such attribute was defined"
              )
            end

            self.attribute(local_name) do |r|
              if fallback
                local = local_attr[r]
                next local unless local.nil?
              end

              record = r.send(association[:name])
              foreign_api.attributes[name][record] if record
            end

            foreign_sql = foreign_api.meta_attributes[name][:sql]

            return unless foreign_sql && !foreign_api.meta_attributes[name][:joins] &&
                          (!fallback || (local_meta_attr[:sql] && !local_meta_attr[:joins]))

            query = model.left_joins(association[:name].to_sym).group(:id).where(<<-SQL.squish)
              #{model.quoted_table_name}."id" = "driver"."id"
            SQL
            .select %(#{model.quoted_table_name}."id")

            if fallback
              query = query.select <<-SQL.squish
                COALESCE(#{local_meta_attr[:sql]}, FIRST(#{foreign_sql}))
                AS "#{association[:name]}_#{name}"
              SQL
            else
              query = query.select %(FIRST(#{foreign_sql}) AS "#{association[:name]}_#{name}")
            end

            joins = <<-SQL.squish
              LEFT JOIN LATERAL (#{query.to_sql}) AS "#{association[:name]}_#{name}_query"
              ON "driver"."id" = "#{association[:name]}_#{name}_query"."id"
            SQL

            self.meta(
              local_name,
              joins: joins,
              sql: %("#{association[:name]}_#{name}_query"."#{association[:name]}_#{name}")
            )
          end
        end
      end
    end
  end
end

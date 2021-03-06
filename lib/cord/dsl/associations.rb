module Cord
  module DSL
    module Associations
      extend ActiveSupport::Concern

      included do
        class << self
          def defined_associations
            model
            return @defined_associations if @defined_associations
            return @defined_associations = Hash.new { |h, k| h[k] = {} } if self == ::Cord::BaseApi
            @defined_associations = superclass.defined_associations.deep_dup
          end

          def define_association name, opts, type, mask_type, auto, api
            name = normalize(name)

            if defined_associations[name][:auto] && opts.none?
              warn %(
                association '#{name}' has already been defined through model inference
                (#{self.name})
              ).squish
            end
            defined_associations[name][:name] = name
            defined_associations[name][:type] = type
            defined_associations[name][:mask_type] = mask_type
            defined_associations[name][:auto] = auto
            defined_associations[name][:api] = api
          end

          def has_many association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)
            single = association_name.to_s.singularize
            reflection = model&.reflect_on_association(association_name)

            define_association(
              association_name,
              opts,
              reflection&.macro == :has_many ? :has_many : :virtual,
              :has_many,
              options.delete(:auto),
              api_name
            )

            self.attribute "#{single}_ids", options do |record|
              record.send(association_name).ids.uniq
            end

            if reflection&.macro == :has_many
              query = model.left_joins(association_name).group(:id).where(<<-SQL.squish)
                #{model.quoted_table_name}."id" = "driver"."id"
              SQL
              .select(<<-SQL.squish)
                #{model.quoted_table_name}."id",
                array_remove(array_agg(DISTINCT #{predicted_table_name(reflection)}."id"), NULL) AS "#{single}_ids"
              SQL

              joins = <<-SQL.squish
                LEFT JOIN LATERAL (#{query.to_sql}) AS "#{single}_ids_query"
                ON "driver"."id" = "#{single}_ids_query"."id"
              SQL

              self.meta(
                "#{single}_ids",
                joins: joins,
                sql: %("#{single}_ids_query"."#{single}_ids")
              )
            end

            self.attribute "#{single}_count", options do |record|
              if requested?("#{single}_ids")
                get_attribute("#{single}_ids").size
              else
                record.send(association_name).except(:order).distinct.count
              end
            end

            if reflection&.macro == :has_many
              query = model.left_joins(association_name).group(:id).where(<<-SQL.squish)
                #{model.quoted_table_name}."id" = "driver"."id"
              SQL
              .select <<-SQL.squish
                #{model.quoted_table_name}."id",
                COUNT(DISTINCT #{predicted_table_name(reflection)}."id") AS "#{single}_count"
              SQL

              joins = <<-SQL.squish
                LEFT JOIN LATERAL (#{query.to_sql}) AS "#{single}_count_query"
                ON "driver"."id" = "#{single}_count_query"."id"
              SQL

              self.meta(
                "#{single}_count",
                joins: joins,
                sql: %("#{single}_count_query"."#{single}_count")
              )
            end

            self.macro association_name do |*attributes|
              begin
                api = find_api(api_name)
              rescue => e
                next if self.class.defined_associations[normalize(association_name)][:auto]
                raise e
              end

              load_records(api, get_attribute("#{single}_ids"), attributes) if controller
            end

            self.meta association_name, children: "#{single}_ids", references: api_name
          end

          def has_one association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)
            reflection = model&.reflect_on_association(association_name)

            define_association(
              association_name,
              opts,
              reflection&.macro == :has_one ? :has_one : :virtual,
              :has_one,
              options.delete(:auto),
              api_name
            )

            self.attribute "#{association_name}_id", options do |record|
              record.send(association_name)&.id
            end

            if reflection&.macro == :has_one
              query = model.left_joins(association_name).group(:id).where(<<-SQL.squish)
                #{model.quoted_table_name}."id" = "driver"."id"
              SQL
              .select <<-SQL.squish
                #{model.quoted_table_name}."id",
                FIRST(#{predicted_table_name(reflection)}."id") AS "#{association_name}_id"
              SQL

              joins = <<-SQL.squish
                LEFT JOIN LATERAL (#{query.to_sql}) AS "#{association_name}_id_query"
                ON "driver"."id" = "#{association_name}_id_query"."id"
              SQL

              self.meta(
                "#{association_name}_id",
                joins: joins,
                sql: %("#{association_name}_id_query"."#{association_name}_id")
              )
            end

            self.macro association_name do |*attributes|
              begin
                api = find_api(api_name)
              rescue => e
                next if self.class.defined_associations[normalize(association_name)][:auto]
                raise e
              end

              if controller && get_attribute("#{association_name}_id")
                load_records(api, [get_attribute("#{association_name}_id")], attributes)
              end
            end

            self.meta association_name, children: "#{association_name}_id", references: api_name
          end

          def belongs_to association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)
            reflection = model&.reflect_on_association(association_name)

            define_association(
              association_name,
              opts,
              reflection&.macro == :belongs_to ? :belongs_to : :virtual,
              :belongs_to,
              options.delete(:auto),
              api_name
            )

            self.macro association_name do |*attributes|
              begin
                api = find_api(api_name)
              rescue => e
                next if self.class.defined_associations[normalize(association_name)][:auto]
                raise e
              end

              if controller && get_attribute("#{association_name}_id")
                load_records(api, [get_attribute("#{association_name}_id")], attributes)
              end
            end

            self.meta association_name, children: "#{association_name}_id", references: api_name
          end

          def associations *names
            assert_not_abstract
            assert_not_static
            opts = names.extract_options!
            names = Array.wrap(names[0]) if names.one?
            names.each do |name|
              unless (reflection = model.reflect_on_association(name)&.macro)
                raise ArgumentError, "association '#{name}' was not found on #{model}"
              end
              unless reflection.in? %i[has_one has_many belongs_to]
                raise ArgumentError, "unsupported association type: '#{reflection}'"
              end
              send reflection, name, opts
            end
          end

          def predicted_table_name reflection
            name = reflection.name
            @predicted_table_names ||= {}
            return @predicted_table_names[name] if @predicted_table_names[name]
            table_name = model.left_joins(name).arel.source.right[-1].left.name
            @predicted_table_names[name] = connection.quote_table_name(table_name)
          end
        end
      end
    end
  end
end

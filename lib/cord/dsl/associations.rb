module Cord
  module DSL
    module Associations
      extend ActiveSupport::Concern

      included do
        class << self
          def has_many association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)
            single = association_name.to_s.singularize

            self.attribute "#{single}_ids", options do |record|
              record.send(association_name).ids
            end

            self.attribute "#{single}_count", options do |record|
              if requested?("#{single}_ids")
                get_attribute("#{single}_ids").size
              else
                record.send(association_name).size
              end
            end

            self.macro association_name do |*attributes|
              api = find_api(api_name)
              load_records(api, get_attribute("#{single}_ids"), attributes) if controller
            end

            self.meta association_name, children: "#{single}_ids", references: api_name
          end

          def has_one association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)

            self.attribute "#{association_name}_id", options do |record|
              record.send(association_name)&.id
            end

            self.macro association_name do |*attributes|
              api = find_api(api_name)
              load_records(api, [get_attribute("#{association_name}_id")], attributes) if controller
            end

            self.meta association_name, children: "#{association_name}_id", references: api_name
          end

          def belongs_to association_name, opts = {}
            options = opts.to_options
            api_name = options.delete(:api)&.to_s || find_api_name(association_name)

            self.macro association_name do |*attributes|
              api = find_api(api_name)
              load_records(api, [get_attribute("#{association_name}_id")], attributes) if controller
            end

            self.meta association_name, children: "#{association_name}_id", references: api_name
          end

          def associations *names
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
        end
      end
    end
  end
end

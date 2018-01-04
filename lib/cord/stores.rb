module Cord
  module Stores
    extend ActiveSupport::Concern

    included do
      def self.hash_stores *names
        names = Array.wrap(names[0]) if names.one?
        names.each do |name|
          eval <<-RUBY
            def self.#{name}
              return @#{name} if @#{name}
              @#{name} = {}
              def @#{name}.add name, block = nil
                name = ::Cord::BaseApi.normalize(name)
                self[name] = block || ->(x){ x.send(name) }
              end
              @#{name}
            end
          RUBY
          delegate name, to: :class
        end
      end

      def self.array_stores *names
        names = Array.wrap(names[0]) if names.one?
        names.each do |name|
          eval <<-RUBY
            def self.#{name} *values
              @#{name} ||= []
              @#{name} += values.flatten.map { |x| ::Cord::BaseApi.normalize(x) } if values.any?
              @#{name}
            end

            def #{name}
              self.class.#{name}
            end
          RUBY
        end
      end
    end
  end
end

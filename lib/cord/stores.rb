module Cord
  module Stores
    extend ActiveSupport::Concern

    included do
      def self.hash_stores *names
        names = Array.wrap(names[0]) if names.one?
        names.each do |name|
          eval <<-RUBY
            def self.#{name} *values
              unless @#{name}
                @#{name} = (self == Cord::BaseApi ? {} : superclass.#{name}.deep_dup)

                def @#{name}.add *names, &block
                  names.flatten.each do |name|
                    self[name] = block || ->(x){ x.send(name) }
                  end
                end

                def @#{name}.remove *names
                  names.flatten.map { |x| ::Cord::BaseApi.normalize(x) }.each do |name|
                    delete(name)
                  end
                end

                def @#{name}.[] key
                  super ::Cord::BaseApi.normalize(key)
                end

                def @#{name}.[]= key, value
                  super ::Cord::BaseApi.normalize(key), value
                end
              end

              @#{name}.add values

              @#{name}
            end

            def self.#{name}= value
              #{name}.replace(value.keys.map { |k| [normalize(k), value[k]] }.to_h)
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
              unless @#{name}
                @#{name} = (self == Cord::BaseApi ? [] : superclass.#{name}.deep_dup)

                def @#{name}.add *names
                  replace(self | names.flatten.map { |x| ::Cord::BaseApi.normalize(x) })
                end

                def @#{name}.remove *names
                  replace(self - names.flatten.map { |x| ::Cord::BaseApi.normalize(x) })
                end
              end

              @#{name}.add values

              @#{name}
            end

            def self.#{name}= value
              #{name}.replace(value.map { |x| normalize(x) })
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

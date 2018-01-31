module Cord
  module DSL
    module BeforeActions
      extend ActiveSupport::Concern

      included do
        hash_stores :before_actions

        class << self
          def before_action name, opts = {}, &block
            name = normalize(name)
            only, except = process_before_action_options opts

            unless before_actions[name]
              before_actions[name] = {
                block: (block || ->(x){ x.send(name) }),
                only: only,
                except: except
              }
              return
            end

            if block
              raise ArgumentError, "before action '#{name}' already exists with a different block"
            end

            if before_actions[name][:only] && only
              return before_actions[name][:only] += only
            end

            if before_actions[name][:except] && except
              return before_actions[name][:except] += except
            end

            raise ArgumentError, %(
              cannot extend before action '#{name}' with '#{only ? 'only' : 'except'}', as it was
              originally defined with '#{before_actions[name][:only] ? 'only' : 'except'}'.
            ).squish
          end

          def skip_before_action name, opts = {}
            unless before_actions[name]
              raise ArgumentError, "before action '#{name}' is undefined"
            end
            only, except = process_before_action_options opts
            if only
              if before_actions[name][:only]
                before_actions[name][:only] -= only
              else
                before_actions[name][:except] += only
              end
            elsif except
              if before_actions[name][:only]
                before_actions[name][:only] &= except
              else
                before_actions[name][:only] = except - before_actions[name].delete(:except)
              end
            else
              before_actions.delete(name)
            end
          end

          def process_before_action_options opts
            options = opts.to_options
            options.assert_valid_keys :only, :except
            if options[:only] && options[:except]
              raise ArgumentError, 'provide either :only or :except, not both'
            end
            if options[:only]
              only = Array.wrap(options[:only]).map { |x| normalize(x) }
              except = nil
            else
              only = nil
              except = Array.wrap(options[:except]).map { |x| normalize(x) }
            end
            [only, except]
          end
        end
      end
    end
  end
end

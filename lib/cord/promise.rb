module Cord
  class Promise
    def initialize
      raise ArgumentError, 'no block given' unless block_given?
      @callbacks = {
        then: -> {},
        catch: -> (e) {},
        finally: -> {}
      }
      @resolved = false
      @lock = Mutex.new

      Thread.new {
        begin
          result = yield
          resolve!
          safe_call(@callbacks[:then], result)
        rescue => e
          resolve!
          safe_call(@callbacks[:catch], e)
        ensure
          @callbacks[:finally].call
        end
      }
    end

    def then &block
      raise ArgumentError, 'no block given' unless block_given?
      @lock.synchronize do
        error_if_resolved
        @callbacks[:then] = block
      end
      self
    end

    def catch &block
      raise ArgumentError, 'no block given' unless block_given?
      @lock.synchronize do
        error_if_resolved
        @callbacks[:catch] = block
      end
      self
    end

    def finally &block
      raise ArgumentError, 'no block given' unless block_given?
      @lock.synchronize do
        error_if_resolved
        @callbacks[:finally] = block
      end
      self
    end

    def resolved?
      @lock.synchronize { @resolved }
    end

    def resolve!
      @lock.synchronize { @resolved = true }
    end

    private

    def error_if_resolved
      raise ResolvedError, 'cannot modify resolved promise' if @resolved
    end

    def safe_call block, arg
      block.arity == 0 ? block.call : block.call(arg)
    end

    ResolvedError = Class.new(StandardError)
  end
end

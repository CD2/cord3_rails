module Cord
  class Promise
    def initialize
      raise ArgumentError, 'no block given' unless block_given?
      @thread = Thread.new { @result = yield }
    end

    def then &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new { safe_call(block, unsafe_await) }
    end

    def catch &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new do
        begin
          unsafe_await
        rescue => e
          safe_call(block, e)
        end
      end
    end

    def finally &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new do
        begin
          unsafe_await
        rescue
        ensure
          block.call
        end
      end
    end

    def await
      unsafe_await rescue nil
    end

    private

    def unsafe_await
      @thread.join
      @result
    end

    def safe_call block, arg
      block.arity == 0 ? block.call : block.call(arg)
    end
  end
end

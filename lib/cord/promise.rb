module Cord
  class Promise
    def initialize
      raise ArgumentError, 'no block given' unless block_given?
      @thread = Thread.new { @result = yield }
    end

    def then &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new { safe_call(block, await) }
    end

    def catch &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new do
        begin
          await
        rescue => e
          safe_call(block, e)
        end
      end
    end

    def finally &block
      raise ArgumentError, 'no block given' unless block_given?
      self.class.new do
        # See https://bugs.ruby-lang.org/issues/13882 for I'm not using 'ensure'
        await rescue nil
        block.call
      end
    end

    def await
      @thread.join
      @result
    end

    private

    def safe_call block, arg
      block.arity == 0 ? block.call : block.call(arg)
    end
  end
end

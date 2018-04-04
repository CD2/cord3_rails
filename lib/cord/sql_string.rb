module Cord
  class SQLString
    def initialize obj = nil
      if Cord.helpers.is_driver?(obj)
        self.sql = obj.to_sql
      else
        self.sql = obj.to_s
      end
    end

    def valid?
      begin
        run
        true
      rescue
        false
      end
    end

    def run
      ::ActiveRecord::Base.connection.execute(sql_with_variables)
    end

    def run_async
      ::ActiveRecord::Base.connection.send(:log, sql_with_variables, 'Async SQL') {}
      Promise.new { ::ActiveRecord::Base.logger.silence { response = run } }
    end

    attr_reader :sql

    def sql= str
      @sql = str.to_s
      @variables = nil
      @variable_keys = nil
    end

    def to_s
      sql_with_variables
    end

    def inspect
      sql_with_variables
    end

    def explain
      cmd = sql_with_variables
      cmd = "EXPLAIN #{cmd}" unless cmd.match(/\Aexplain/i)
      response = ::ActiveRecord::Base.connection.execute(cmd)
      puts
      response.values.flatten.map { |x| puts x }
      puts
      self
    end

    def has_variable? k
      k = symbolize(k)
      @variable_keys ||= sql.scan(/(?<!:):([a-zA-Z]\w*)/).flatten.uniq.map { |k| symbolize(k) }
      @variable_keys.include?(k)
    end

    def variables
      @variables ||= {}
    end

    def []= k, v
      k = symbolize(k)
      raise ArgumentError, "statement has no variable :#{k}" unless has_variable?(k)
      variables[k] = v
    end

    def [] k
      k = symbolize(k)
      variables[k]
    end

    def sql_with_variables
      sql.gsub(/(?<!:):([a-zA-Z]\w*)/) do
        variables.has_key?(symbolize($1)) ? Cord.helpers.escape_sql(self[$1]) : ":#{$1}"
      end
    end

    def strip_comments!
      @sql = sql.gsub(/\/\*.*?\*\/|--.*?\n/s, '')
      self
    end

    def strip_comments
      dup.strip_comments!
    end

    def compact!
      @sql = sql.squish
      self
    end

    def compact
      dup.compact!
    end

    def assign! vars = {}
      vars.each { |k, v| self[k] = v }
      self
    end

    def assign vars = {}
      result = dup
      result.instance_variable_set(:@variables, variables.dup)
      vars.each { |k, v| result[k] = v }
      result
    end

    def safe_assign! vars = {}
      vars.each do |k, v|
        k = symbolize(k)
        variables[k] = v if has_variable?(k)
      end
      self
    end

    def safe_assign vars = {}
      result = dup
      result.instance_variable_set(:@variables, variables.dup)
      result.safe_assign!(vars)
    end

    def symbolize k
      Cord.helpers.symbolize(k)
    end

    delegate :blank?, :present?, to: :sql
  end
end

module Cord
  class JSONString
    def initialize str = nil
      self.json = str.to_s
    end

    def valid?
      !!object
    end

    def object
      @object ||= JSON.parse(@json) rescue nil
    end

    def object= obj
      @object = obj.as_json
      @json = obj.to_json
    end

    def object?
      !!@object
    end

    attr_reader :json

    def json= str
      @json = str.to_s
      @object = nil
    end

    def to_json *args, &block
      json
    end

    def as_json *args, &block
      object
    end

    def to_s
      json
    end

    def inspect
      if @pretty
        @pretty = false
        "\n" + ::Cord::BaseApi.json_inspect(object)
      else
        json
      end
    end

    def pretty
      @pretty = true
      self
    end

    def method_missing name, *args, &block
      object.send(name, *args, &block)
    end
  end
end

module Cord
  class Attachment
    attr_accessor :name
    attr_accessor :record
    attr_accessor :file

    def initialize name, record, file
      self.name = Cord::BaseApi.normalize name
      self.record = record
      self.file = file
    end

    def cache
      return @cache unless @cache.nil?
      @cache = cache_field ? record.send(cache_field.name) : false
    end

    def cache_field
      return @cache_field unless @cache_field.nil?
      @cache_field = model.columns.detect { |x| x.name == "#{name}_cache" } || false
    end

    def model
      record.class
    end

    def sizes
      @sizes ||= Cord::BaseApi.normalize_hash(
        Cord::BaseApi.normalize_hash(model.cord_image_sizes)[name]
      )
    end

    def url
      file.remote_url
    end

    def as_json *args, &block
      file.as_json *args, &block
    end

    def inspect
      %(#<Cord::Attachment name="#{name}", model=#{model}, record=#{record.id || :new}>)
    end

    def get_size name
      name = Cord::BaseApi.normalize name

      unless sizes[name]
        raise ArgumentError, "unknown size '#{name}', valid sizes are: #{sizes.keys}"
      end

      return file.thumb(sizes[name]).url unless cache
      return cache[name] if cache[name]

      # update the in-memory record
      result = cache[name] = store_new_size(name)

      return result if record.new_record?

      # update the database record
      # this does not reconcile the two copies of the record, meaning get_size can be called on
      # modified records without saving them

      model.connection.execute <<-SQL.squish
        UPDATE #{model.table_name}
        SET #{cache_field.name} = jsonb_set(
          #{cache_field.name}#{'::jsonb' unless cache_field.type == :jsonb},
          '{#{name}}',
          '"#{result}"',
          true
        )
        WHERE id = #{record.id}
      SQL

      result
    end

    def store_new_size size
      parts = file.name.to_s.split('.')
      parts.size > 1 ? parts[-2] += "_#{size}" : parts = ["#{file.name}_#{size}"]
      uid = Dragonfly.app.store file.thumb(sizes[size]), 'name' => parts.join('.')
      Dragonfly.app.remote_url_for(uid)
    end
  end
end

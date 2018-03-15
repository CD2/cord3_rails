module Cord
  class Attachment
    attr_accessor :name
    attr_accessor :record

    def initialize name, record
      self.name = Cord::BaseApi.normalize name
      self.record = record
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
      add_host Dragonfly.app.remote_url_for(uid)
    end

    def file_name
      @file_name ||= model.column_names.include?("#{name}_name") ? record.send("#{name}_name") : ''
    end

    def file
      Dragonfly.app.fetch(uid)
    end

    def uid
      record.send "#{name}_uid"
    end

    def as_json *args, &block
      { uid: uid, name: file_name }
    end

    def inspect
      %(#<Cord::Attachment name="#{name}", model=#{model}, record=#{record.id || :new}>)
    end

    def destroy_cached_images
      Cord::BaseApi.async_map(cache.values) { |url| Dragonfly.app.destroy url_to_uid(url) }
    end

    def reload_cache
      destroy_cached_images
      Cord::BaseApi.async_map(sizes.keys) { |size| [size, store_new_size(size)] }.to_h
    end

    def get_size name
      name = Cord::BaseApi.normalize name

      unless sizes[name]
        raise ArgumentError, "unknown size '#{name}', valid sizes are: #{sizes.keys}"
      end

      return file.thumb(sizes[name]).url unless cache
      return cache[name] if cache[name]
      return nil unless Cord.generate_missing_images

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
      parts = file_name.to_s.split('.')
      parts.size > 1 ? parts[-2] += "_#{size}" : parts = ["#{file_name}_#{size}"]
      uid = Dragonfly.app.store file.thumb(sizes[size]), 'name' => parts.join('.')
      add_host Dragonfly.app.remote_url_for(uid)
    end

    def add_host url
      return url unless url[0] == '/' && Dragonfly.app.server.url_host
      Dragonfly.app.server.url_host.chomp('/') + url
    end

    def url_to_uid url
      route = Dragonfly.app.datastore.instance_eval { root_path.gsub(server_root, '') }
      url.partition(route)[2].gsub /\A\//, ''
    end
  end
end

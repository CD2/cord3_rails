# frozen_string_literal: true

module Cord
  class RecordHandler < Handler
    # {
    #   id: '',
    #   type: 'record',
    #   data: {
    #     api: '',
    #     id: '',
    #     attributes: ['']
    #   }
    # }

    def validate_each(blob)
      return unless (api = validate_api(blob))
      validate_id(blob) && validate_attributes(blob, api)
    end

    def validate_api(blob)
      api_name = blob[:data][:api] = normalize(blob[:data][:api])

      if api_name.blank?
        error(blob, :server, type: :noApi, message: 'no api specified')
        return nil
      end

      begin
        strict_find_api(api_name)
      rescue NameError => e
        error(blob, :server, type: :noApi, message: e.message)
        nil
      end
    end

    def validate_id(blob)
      blob[:id] ||= normalize(blob[:id])
      return true if blob[:id].present?
      error(blob, :server, type: :noId, message: 'no id specified')
      false
    end

    def validate_attributes(blob, api)
      attributes = blob[:data][:attributes] = _normalize(Array.wrap(blob[:data][:attributes])).sort
      missing = attributes.reject { |name| api.attributes[name] }
      return true if missing.none?

      error(
        blob,
        :server,
        type: :noAttribute,
        message: "#{missing} did not match any keywords defined for #{api}"
      )

      false
    end

    def process(all_blobs)
      all_blobs.group_by { |blob| blob[:data][:api] }.each do |api_name, api_blobs|
        records = {}
        api = controller.load_api(api_name)
        api_blobs.group_by { |blob| blob[:attributes] }.each do |attrs, blobs|
          records.merge! get_records(api, attrs, blobs)
        end
        api_blobs.each do |blob|
          render_record(blob, records)
        end
      end
    end

    def get_records(api, attrs, blobs)
      ids = blobs.map { |blob| blob[:data][:id] }
      api.render_records(ids, attrs).group_by { |record| record['id'].to_s }
    end

    def render_record(blob, records)
      record = records[blob[:id]]
      if !record || record['error']
        error blob, :notFound
      else
        render blob, record
      end
    end
  end
end

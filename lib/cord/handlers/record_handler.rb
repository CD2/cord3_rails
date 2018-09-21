module Cord
  class RecordHandler < Handler
    # {
    #   api: '',
    #   id: '',
    #   attributes: ['']
    # }

    def process blobs
      blobs.group_by { |b| b['data']['api'] }.each do |api_name, blobs|
        ids = blobs.map { |b| b['data']['id'] }.uniq
        attributes = blobs.map { |b| b['data']['attributes'] }.flatten.uniq
        records = Cord.helpers.find_api(api_name).render_records(ids, attributes, beta: true)
        blobs.each do |blob|
          record = records.detect { |r| r['id'].to_s == blob['data']['id'].to_s }
          if !record || record['error']
            error blob, :notFound
          else
            render blob, record
          end
        end
      end
    end

    def process_each(blob)
      render blob, Cord.helpers.find_api(blob['data']['api']).render_records([blob['data']['id']], blob['data']['attributes'])[0]
    rescue Cord::RecordNotFound
      error blob, :notFound
    end
  end
end

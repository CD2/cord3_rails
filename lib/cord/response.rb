# frozen_string_literal: true

class Response
  def body
    @body ||= {}
  end

  def initialize(blobs)
    @blobs = blobs
  end

  def respond_data(blobs, data)
    Array.wrap(blobs).each do |blob|
      respond blob, data: data
    end
  end

  def respond_error(blobs, name, data = nil)
    Array.wrap(blobs).each do |blob|
      respond blob, error: { type: name, data: data }
    end
  end

  def respond(blob, data)
    raise 'responded to the same blob twice' if responded_to?(blob)
    body[blob[:id]] = data
  end

  def responded_to?(blob)
    body.key? blob[:id]
  end

  def unhandled_blobs(blobs = @blobs)
    blobs.reject { |blob| responded_to? blob }
  end

  def finalize!
    respond_error unhandled_blobs, :server, type: :unhandled, message: 'handler did not respond'
    freeze
  end

  def to_json
    body.map { |key, value| value.merge(id: key) }
  end
end

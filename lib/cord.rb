require 'cord/engine'
require 'cord/base_api'

Dir["#{Cord::Engine.root}/lib/cord/spec/**/*.rb"].each { |f| require f }


module Cord
  class << self
    mattr_accessor :action_on_error
    self.action_on_error = :log
    # self.action_on_error = :raise
    # self.action_on_error = nil

    mattr_accessor :default_image_sizes
    self.default_image_sizes = {}
    # self.default_image_sizes = { thumbnail_stretch: '75x75', thumbnail_crop: '75x75#' }
  end
end

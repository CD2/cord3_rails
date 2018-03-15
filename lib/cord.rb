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

    # This option determines the behviour when requesting an image not present in the cache:
    #   true: generate the image before responding
    #   false: return nil
    # When no cache is present, images will always be generated on-demand, ignoring this setting.
    # When set to false, you should manually populate the caches with reload_#{field}_cache().
    mattr_accessor :generate_missing_images
    self.generate_missing_images = true
  end
end

require 'cord/engine'
require 'cord/base_api'

Dir["#{Cord::Engine.root}/lib/cord/spec/**/*.rb"].each { |f| require f }


module Cord
  def self.config_setting name, default: nil, choices: nil
    mattr_reader name
    if choices
      define_singleton_method "#{name}=" do |obj|
        raise ArgumentError, "#{name} must be one of #{choices}" unless obj.in? choices
        class_variable_set("@@#{name}", obj)
      end
    else
      mattr_writer name
    end
    send("#{name}=", default)
  end

  # Determines the behviour when an error is encountered while rendering a response
  #   :log => add the error to the _errors response and print a backtrace in the console
  #   :raise => render a 500 error
  #   nil => silently swallow the error
  # This includes those raised by calling error() in an action
  config_setting :action_on_error, default: :log, choices: [:log, :raise, nil]

  # The different image versions to be cached for images
  # Eg. { thumbnail_stretch: '75x75', thumbnail_crop: '75x75#' }
  config_setting :default_image_sizes, default: {}

  # Determines the behviour when requesting an image not present in the cache:
  #   :generate => return the url for a dragonfly job which will generate the image (slow)
  #   :save => generate, save and cache the image before responding (very slow)
  #   nil => return nil (very fast)
  # When no cache is present, images will always use :generate, ignoring this setting
  # When set to nil, you should manually populate the caches with reload_#{field}_cache()
  config_setting :action_on_missing_image, default: :generate, choices: [:generate, :save, nil]

  # Ignores all default api scopes, useful for testing/debugging
  config_setting :disable_default_scopes, default: false

  # How long to hold record caches before regenerating them, unless specified otherwise
  config_setting :default_cache_lifespan, default: 5.minutes
end

require 'cord/engine'
require 'cord/active_record'
require 'cord/base_api'

require 'binding_of_caller'

Dir["#{Cord::Engine.root}/lib/cord/spec/**/*.rb"].each { |f| require f }

module Cord
  def self.config_setting name, default: nil, choices: nil, type: nil
    mattr_reader name
    if choices
      define_singleton_method "#{name}=" do |obj|
        raise ArgumentError, "#{name} must be one of #{choices}" unless obj.in? choices
        class_variable_set("@@#{name}", obj)
      end
    elsif type
      define_singleton_method "#{name}=" do |obj|
        raise ArgumentError, "#{name} must be a #{type}" unless obj.is_a? type
        class_variable_set("@@#{name}", obj)
      end
    else
      mattr_writer name
    end
    send("#{name}=", default)
  end

  def self.configure
    yield self
  end

  # Determines the behviour when an error is encountered while rendering a response
  #   :log => add the error to the _errors response and print a backtrace in the console
  #   :raise => render a 500 error
  #   nil => silently swallow the error
  # This includes those raised by calling error() in an action
  config_setting :action_on_error, default: :log, choices: [:log, :raise, nil]

  # Runs on every error
  config_setting :after_error, type: Proc, default: -> (e) {}

  # When false, warnings will be not be printed in the console or added to the _warnings response
  config_setting :log_warnings, default: true

  # Determines the behviour when a given unpermitted params in an action
  #   :warn => create a warning (behaviour defined by :log_warnings)
  #   :error => create an error (behaviour defined by :action_on_error)
  #   nil => ignore unpermitted parameters
  config_setting :action_on_unpermitted_parameters, default: :warn, choices: [:warn, :error, nil]

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

  # TODO: remove the api base controller and these methods

  # The superclass to use for the ApiBaseController
  config_setting :parent_controller, default: 'ActionController::API'

  # A callback for extending the api base controller
  config_setting :after_controller_load, default: -> {}, type: Proc
end

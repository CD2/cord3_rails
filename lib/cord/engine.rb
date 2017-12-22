module Cord
  class Engine < ::Rails::Engine
    isolate_namespace Cord
    # config.autoload_paths << File.expand_path '../app/apis', __FILE__
  end
end

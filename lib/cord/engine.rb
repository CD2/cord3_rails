module Cord
  class Engine < ::Rails::Engine
    isolate_namespace Cord
    # config.autoload_paths << File.expand_path '../app/apis', __FILE__

    initializer "cord.active_record" do
      ActiveSupport.on_load :active_record do
        require_relative './active_record'
      end
    end

    initializer "cord.action_controller" do
      ActiveSupport.on_load :action_controller do
        AbstractController::Base.send :define_method, :cord_controller? do
          is_a? ::Cord::ApiBaseController
        end
      end
    end

    initializer :append_migrations do |app|
      config.paths['db/migrate'].expanded.each do |expanded_path|
        app.config.paths['db/migrate'] << expanded_path
      end
    end
  end
end

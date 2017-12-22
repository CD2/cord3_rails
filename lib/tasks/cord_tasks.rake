# frozen_string_literal: true

namespace :cord do
  desc 'does the docs'
  task document_actions: :environment do
    require_dependency "#{::Cord::Engine.root}/lib/action_writer.rb"
    ActionWriter.write_actions
  end
end

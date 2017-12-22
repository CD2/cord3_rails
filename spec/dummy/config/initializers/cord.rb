# frozen_string_literal: true

AbstractController::Base.send :include, Cord::ApplicationHelper
Cord.action_writer_path = Rails.root.join 'actions.md'
Cord.enable_postgres_rendering = true

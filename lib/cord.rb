require "cord/engine"
require "cord/base_api"

module Cord
  class << self
    mattr_accessor :action_writer_path
    mattr_accessor :enable_postgres_rendering
    mattr_accessor :raise_on_crud_error
    self.action_writer_path = '/'
    self.enable_postgres_rendering = false
    self.raise_on_crud_error = false
  end
end

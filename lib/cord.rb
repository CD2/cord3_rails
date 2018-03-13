require "cord/engine"
require "cord/base_api"

module Cord
  class << self
    mattr_accessor :action_on_error
    self.action_on_error = :log
    # self.action_on_error = :raise
  end
end

module Cord
  module ApplicationHelper
    def cord_controller?
      Cord.in? self.class.parents
    end
  end
end

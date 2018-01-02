module Product
  class Variant < ApplicationRecord
    belongs_to :product
  end
end

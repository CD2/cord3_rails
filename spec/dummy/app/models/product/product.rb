module Product
  class Product < ApplicationRecord
    has_many :variants
  end
end

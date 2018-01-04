module Product
  class ProductsApi < ApplicationApi
    has_many :variants
    has_many :articles
  end
end

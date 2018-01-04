module Product
  class ProductsApi < ApplicationApi
    model Product::Product

    has_many :variants
    has_many :articles
  end
end

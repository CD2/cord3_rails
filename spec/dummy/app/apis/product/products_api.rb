module Product
  class ProductsApi < ApplicationApi
    model Product::Product

    has_many :variants
  end
end

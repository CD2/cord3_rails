module Product
  class VariantsApi < ApplicationApi
    model Product::Variant

    belongs_to :product
  end
end

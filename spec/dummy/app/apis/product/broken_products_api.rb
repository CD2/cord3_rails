class Product::BrokenProductsApi < ApplicationApi
  model Product::Product

  def initialize *args, &block
    super
    raise 'an error'
  end
end

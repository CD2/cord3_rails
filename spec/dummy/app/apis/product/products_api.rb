class Product::ProductsApi < ApplicationApi
  has_many :variants
  has_many :articles

  scope(:raise) { raise 'an error' }

  action(:raise) { raise 'an error' }
  action(:error) { error 'an error' }
end

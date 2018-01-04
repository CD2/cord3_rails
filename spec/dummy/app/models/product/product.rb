module Product
  class Product < ApplicationRecord
    has_many :variants
    has_many :articles, class_name: 'Comment', foreign_key: :id
  end
end

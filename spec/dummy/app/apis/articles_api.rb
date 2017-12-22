class ArticlesApi < ApplicationApi
  model Article

  attribute :constant_thing do |r|
    'test'
  end

  has_many :comments
end

class ArticlesApi < ApplicationApi
  model Article

  custom_alias(:home) { 1 }
  alias_columns :url

  attribute :constant_thing do |r|
    'test'
  end

  has_many :comments
end

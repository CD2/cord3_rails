class ArticlesApi < ApplicationApi
  custom_alias(:home) { 1 }
  alias_columns :url

  attribute :constant_thing do |r|
    'test'
  end

  searchable_columns :name

  associations :comments
end

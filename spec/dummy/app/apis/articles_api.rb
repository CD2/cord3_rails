class ArticlesApi < ApplicationApi
  custom_alias(:home) { 1 }
  alias_columns.add :url

  attribute :constant_thing do |r|
    'test'
  end

  searchable_columns.add :name

  associations :comments
end

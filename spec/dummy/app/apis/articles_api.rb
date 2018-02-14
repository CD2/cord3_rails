class ArticlesApi < ApplicationApi
  default_scope { |d| d.order(id: :desc) }

  custom_alias(:home) { 1 }
  alias_columns.add :url

  attribute :constant_thing do |r|
    'test'
  end

  searchable_columns.add :name

  associations :comments, :image

  collection do
    before_action(:a, only: :nested_actions) { render before_action: ':nested_actions' }

    action :nested_actions do
      error 'a top level error'
      results = []
      results << perform_action(:echo, data: { 'some' => 'data' })
      results << perform_action(:error)
      results << perform_action(:before)
      results << perform_action(:before, before_actions: true)
      results << perform_action(:halt)
      render results: results
    end

    action :echo do
      render data.permit!
    end

    action :error do
      error 'a nested error'
    end

    before_action(:b, only: :before) { render before_action: ':before' }

    action :before do
      render action: ':before'
    end

    action :halt do
      halt! 'a nested halt'
    end
  end
end

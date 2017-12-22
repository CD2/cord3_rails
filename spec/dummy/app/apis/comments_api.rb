class CommentsApi < ApplicationApi
  model Comment

  default_scope :all

  scope :scope1, &:all
  scope :scope2, &:all

  attribute(:id2) do
    get(:id) * 2
  end

  attribute :id4 do
    if requested?(:id2)
      get(:id2) * 2
    end
  end

  crud_actions :create, :update, :destroy
  permit_params :body, :article_id
end

class NotesApi < ApplicationApi
  model Comment

  default_scope do |driver|
    current_user ? driver.where(id: current_user.comments) : driver.none
  end
end

class ArticlesApi < ApplicationApi
  default_scope &:published

  attribute :first_comment_id do |record|
    get(:comment_ids).first
  end

  associations :videos, :image, :author
  # == Generates ==>
    # via driver reflection
    has_many :videos
    has_one :image
    belongs_to :author
  # <===============

  has_one :address

  :address
  :address_id

  macro :address do
    if attributes[:address]
      @record_json.merge! get(:address)
    else
      keyword_missing(:address)
    end
  end

  has_many :comments, api: NotesApi
  # == Generates ==>
    attribute :comment_ids do |record|
      record.comments.ids
    end

    attribute :comment_count do |record|
      requested?(:comment_ids) ? get(:comment_ids).size : record.comments.count
    end

    macro :comments do |attributes|
      load_records(NotesApi, get(:comment_ids), attributes)
    end

    meta :comments, children: :comment_ids, references: NotesApi
  # <===============

  has_one :image
  # == Generates ==>
    attribute :image_id do |record|
      record.image&.ids
    end

    macro :image do |attributes|
      load_records(ImagesApi, [get(:image_id)], attributes)
    end

    meta :image, children: :image_id, references: ImagesApi
  # <===============

  belongs_to :author, api: :users
  # == Generates ==>
    macro :author do |attributes|
      load_records(UsersApi, [get(:author_id)], attributes)
    end

    meta :author, references: UsersApi
  # <===============


  action :member_something do |record|

  end

  collection do
    action :collection_something do

    end
  end
end

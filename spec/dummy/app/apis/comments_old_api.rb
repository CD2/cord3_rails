class CommentsOldApi < ApplicationApi
  driver Comment

  belongs_to :article
end

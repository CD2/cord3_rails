class CreateArticles < ActiveRecord::Migration[5.1]
  def change
    create_table :articles do |t|
      t.string :name
      t.integer :article_type
      t.string :url, unique: true, null: false, index: true, default: -> { 'md5((random())::text)' }

      t.timestamps
    end
  end
end

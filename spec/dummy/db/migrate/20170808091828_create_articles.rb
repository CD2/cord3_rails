class CreateArticles < ActiveRecord::Migration[5.1]
  def change
    create_table :articles do |t|
      t.string :name
      t.integer :article_type

      t.timestamps
    end
  end
end

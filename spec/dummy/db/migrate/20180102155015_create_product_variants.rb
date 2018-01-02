class CreateProductVariants < ActiveRecord::Migration[5.1]
  def change
    create_table :product_variants do |t|
      t.string :name
      t.references :product, foreign_key: { to_table: :product_products }

      t.timestamps
    end
  end
end

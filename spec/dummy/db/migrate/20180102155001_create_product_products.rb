class CreateProductProducts < ActiveRecord::Migration[5.1]
  def change
    create_table :product_products do |t|
      t.string :name

      t.timestamps
    end
  end
end

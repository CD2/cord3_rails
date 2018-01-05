class CreateInventoryStockEntries < ActiveRecord::Migration[5.1]
  def change
    create_table :inventory_stock_entries do |t|
      t.string :name

      t.timestamps
    end
  end
end

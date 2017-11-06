class CreateValues < ActiveRecord::Migration
  def change
    create_table :values do |t|
      t.integer :coincheck_bid
      t.integer :coincheck_ask
      t.integer :zaif_bid
      t.integer :zaif_ask

      t.timestamps null: false
    end
  end
end

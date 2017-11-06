class CreateAssets < ActiveRecord::Migration
  def change
    create_table :assets do |t|
      t.float :coincheck_jpy
      t.float :coincheck_btc
      t.float :zaif_jpy
      t.float :zaif_btc

      t.timestamps null: false
    end
  end
end

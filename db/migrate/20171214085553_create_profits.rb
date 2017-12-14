class CreateProfits < ActiveRecord::Migration
  def change
    create_table :profits do |t|
      t.float :profit
      t.float :amount
      t.string :order
      t.float :per1BtcProfit

      t.timestamps null: false
    end
  end
end

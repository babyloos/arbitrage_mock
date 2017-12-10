class CreateProfits < ActiveRecord::Migration
  def change
    create_table :profits do |t|
      t.float :buy_coincheck
      t.float :buy_zaif

      t.timestamps null: false
    end
  end
end

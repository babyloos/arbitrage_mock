class CreateAdjustLogs < ActiveRecord::Migration
  def change
    create_table :adjust_logs do |t|
      t.string :toExchanges
      t.string :type
      t.float :amount

      t.timestamps null: false
    end
  end
end

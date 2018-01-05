class CreateResetLogs < ActiveRecord::Migration
  def change
    create_table :reset_logs do |t|
      t.integer :asset_id

      t.timestamps null: false
    end
  end
end

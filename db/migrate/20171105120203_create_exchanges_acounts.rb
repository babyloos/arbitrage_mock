class CreateExchangesAcounts < ActiveRecord::Migration
  def change
    create_table :exchanges_acounts do |t|
      t.string :coincheck_api_key
      t.string :coincheck_secret_key
      t.string :zaif_api_key
      t.string :zaif_secret_key

      t.timestamps null: false
    end
  end
end

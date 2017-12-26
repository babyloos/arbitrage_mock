class CreateTradeInfos < ActiveRecord::Migration
  def change
    create_table :trade_infos do |t|
      t.float :amount
      t.float :count
      t.float :profit1btc
      t.float :profitAmount
      t.float :needProfit1btc
      t.float :needProfitAmount

      t.timestamps null: false
    end
  end
end

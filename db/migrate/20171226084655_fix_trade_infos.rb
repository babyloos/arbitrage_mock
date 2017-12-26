class FixTradeInfos < ActiveRecord::Migration
  def change
    add_column :trade_infos, :trade, :boolean, default: false, null: false
  end
end

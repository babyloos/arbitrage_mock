class AddTradeInfos < ActiveRecord::Migration
  def change
    add_column :trade_infos, :order, :string
  end
end

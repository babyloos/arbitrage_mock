namespace :update_value do
    
    desc "仮想通貨の価格情報を更新"
    
    task :update => :environment do
        include ArbitrageMock
        # jpy = 1000000
        # btc = 1600000 / jpy
        # asset = {coincheck_jpy: jpy, coincheck_btc: btc, zaif_jpy: jpy, zaif_btc: btc}
        asset = Asset.last
        d = ArbitrageMock::ArbitrageMock.new(asset)
        d.debug
    end
    
    # task :update => :environment do 
    #     include Arbitrage
    #     d = DataUpdate.new
    #     # sleep(1)
    #     while true do
    #         puts "-------------------"
    #         d.updateValue
    #         d.trade
    #         d.updateAsset
    #         sleep(1)
    #     end
    # end
    
    # task :adjustJpy => :environment do
    #     include Arbitrage
    #     p "資金調整(JPY)"
    #     p "両取引所のJPY資産が同じになるよう資金移動します"
    #     DataUpdate::adjustAssetJpy_demo
    # end
    
    # task :calcProfit => :environment do
    #     include Arbitrage
    #     d = DataUpdate.new
    #     while true do
    #         sleep(1)
    #         profit = d.profitWithAmount
    #         profit[:per1btc] = profit[:profit] / profit[:amount]
    #         profit[:created] = Time.now
    #         puts "----------------------------"
    #         p profit
    #     end
    # end
end

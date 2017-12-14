namespace :update_value do
    
    desc "仮想通貨の価格情報を更新"
    
    task :update => :environment do 
        include Arbitrage
        d = DataUpdate.new
        p "initialize"
        p "------------------"
        sleep(1)
        while true do
            p "updateValue"
            d.updateValue
            p "updateAsset"
            d.updateAsset
            # p "updateProfit"
            # d.profit
            d.trade
            sleep(1)
            p "-------------------"
        end
    end
    
    task :adjustJpy => :environment do
        include Arbitrage
        p "資金調整(JPY)"
        p "両取引所のJPY資産が同じになるよう資金移動します"
        DataUpdate::adjustAssetJpy_demo
    end
    
    task :calcProfit => :environment do
        include Arbitrage
        d = DataUpdate.new
        while true do
            sleep(1)
            profit = d.profitWithAmount
            profit[:per1btc] = profit[:profit] / profit[:amount]
            profit[:created] = Time.now
            puts "----------------------------"
            p profit
        end
    end
end

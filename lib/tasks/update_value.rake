namespace :update_value do
    
    desc "仮想通貨の価格情報を更新"
    
    task :update => :environment do 
        include Arbitrage
        d = DataUpdate.new
        p "initialize"
        sleep(1)
        while true do
            p "-------------------"
            p "updateValue"
            d.updateValue
            p "updateAsset"
            d.updateAsset
            p "updateProfit"
            d.profit
            # d.trade
            sleep(1)
            p "-------------------"
        end
    end
end

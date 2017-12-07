namespace :update_value do
    
    desc "仮想通貨の価格情報を更新"
    
    task :update => :environment do 
        include Arbitrage
        d = DataUpdate.new
        while true do
            d.updateValue
            p "update value"
            d.profit
            p "profit"
            d.trade
            p "trade"
            sleep(1)
        end
    end
end

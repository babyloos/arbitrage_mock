
=begin

    裁定取引に関わる処理全般を行う
    -- 価格取得 --
    -- 売買判断 --
        
=end
module Arbitrage
    extend ActiveSupport::Concern # インスタンスメソッドのみの利用時は記述の必要なし
    # require 'net/http'
    # require 'uri'
    
    class DataUpdate
        include Zaif
        def initialize
            @coincheckApi = CoincheckClient.new("YOUR API KEY", "YOUR SECRET KEY")
            @zaifApi = Zaif::API.new()
        end
        
        def update
            response = @coincheckApi.read_ticker
            coincheckData = JSON.parse(response.body)
            zaifData = @zaifApi.get_ticker("btc")
            asset = Value.new(coincheck_bid: coincheckData["bid"], coincheck_ask: coincheckData["ask"], zaif_bid: zaifData["bid"], zaif_ask: zaifData["ask"])
            asset.save
        end
        
        private
        
    end

    class ProfitCalc
        def initialize
            @value = Value.last
        end
        
        def profit
            {buy_coincheck: @value.zaif_bid - @value.coincheck_ask, buy_zaif: @value.coincheck_bid - @value.zaif_ask}
        end
    end
    
    private
    
    # 各種価格の取得
    
    # def getCoincheckValue
    #     cc = CoincheckClient.new("YOUR API KEY", "YOUR SECRET KEY")
    #     response = cc.read_ticker
    #     JSON.parse(response.body)
    # end
    
end
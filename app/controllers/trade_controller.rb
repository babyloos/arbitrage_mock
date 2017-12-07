class TradeController < ApplicationController
    include Arbitrage
    def home
        # @asset = Asset.last
        # @value = Value.last
        
        # p = DataUpdate.new
        # @profit = p.profit
        
        # UPDATE = DataUpdate.new
        # update.updateValue
        # c = Coincheck.new
        # z = Za.new
        # @coincheckValue = c.getValue
        # @zaifValue = z.getValue
        # byebug
        # @value = {coincheck_bid: value["bid"], coincheck_ask: value["ask"], zaif_bid: }
    end
    
    def ajax
        # 価格情報をjsonで出力
        asset = Asset.last
        value = Value.last
        
        p = DataUpdate.new
        profit = p.profit
        @data = [
            "asset": asset,
            "value": value,
            "profit": profit
        ]
        render :json => @data
    end
end
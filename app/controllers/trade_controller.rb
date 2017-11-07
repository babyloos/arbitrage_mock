class TradeController < ApplicationController
    include Arbitrage
    def home
        @asset = Asset.last
        @value = Value.last
        
        p = ProfitCalc.new
        @profit = p.profit
        
        # update = DataUpdate.new
        # update.update
        # c = Coincheck.new
        # z = Za.new
        # @coincheckValue = c.getValue
        # @zaifValue = z.getValue
        # byebug
        # @value = {coincheck_bid: value["bid"], coincheck_ask: value["ask"], zaif_bid: }
    end
end
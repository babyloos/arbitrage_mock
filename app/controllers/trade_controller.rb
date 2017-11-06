class TradeController < ApplicationController
    include Arbitrage
    def home
        @asset = Asset.last
        sayHello
    end
end
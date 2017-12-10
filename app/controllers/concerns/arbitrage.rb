
=begin

    裁定取引に関わる処理全般を行う
    -- 価格取得 --
    -- 売買判断 --
    
    ZaifAPIのライブラリが使えないから生リクエストしたら使えたのでそれでいきます
    
    
    １度にapiごとのリクエストを一度に行わなければいけない（APIリクエスト数の節約）
        
=end
module Arbitrage
    extend ActiveSupport::Concern # インスタンスメソッドのみの利用時は記述の必要なし
    require 'net/http'
    # require 'uri'
    
    class DataUpdate
        include Zaif
        def initialize
            @production = false
            @coincheckApi = CoincheckClient.new(ENV["COINCHECK_API_KEY"], ENV["COINCHECK_SECRET_KEY"])
            @zaifApi = API.new(api_key: ENV["ZAIF_API_KEY"], api_secret: ENV["ZAIF_API_SECRET"])
            @value = Value.last
            if @production
                @asset = updateAsset
            else
                @asset = Asset.last
            end
            @profit;
        end
        
        # 価格情報の更新
        def updateValue
            response = @coincheckApi.read_ticker
            coincheckData = JSON.parse(response.body)
            zaifData = @zaifApi.get_ticker("btc")
            value = Value.new(coincheck_bid: coincheckData["bid"], coincheck_ask: coincheckData["ask"], zaif_bid: zaifData["bid"], zaif_ask: zaifData["ask"])
            value.save
            @value = Value.last
        end
        
        # 資産情報の更新
        def updateAsset
            if @productino
                # coincheck
                coincheckAsset = JSON.parse(@coincheckApi.read_balance.body)
                # zaif
                zaifAsset = @zaifApi.get_info
                asset = Asset.new(coincheck_jpy: coincheckAsset["jpy"], coincheck_btc: coincheckAsset["btc"],
                                    zaif_jpy: zaifAsset["deposit"]["jpy"], zaif_btc: zaifAsset["deposit"]["btc"])
                asset.save
                asset
            else
                Asset.last
            end
        end
        
        # 本番取引
        def trade
            if @production
                production_trade
            else
                demoTrade
            end
        end
        
        def production_trade
        end
        
         # デモ取引
        def demoTrade
            # 取引量 0.01btc
            amount = 0.01
            p @profit[:buy_coincheck];
            if(@profit[:buy_coincheck] > 0)
                p "buy coincheck"
                p buy_coincheck(amount) ? "売買成功" : "残高不足"
            elsif(@profit[:buy_zaif] > 0)
                p "buy zaif"
                p buy_zaif(amount) ? "売買成功" : "残高不足"
            end
        end
        
        # coincheckで買ってzaifで売る
        def buy_coincheck_demo(amount)
            # 残JPY確認
            # 買い
            buyValue = amount * @value[:coincheck_ask]
            if @asset[:coincheck_jpy] < buyValue
                return false
            else
                @asset[:coincheck_jpy] -= buyValue
                @asset[:coincheck_btc] += amount
            end
            
            # 残BTC確認
            # 売り
            sellValue = amount * @value[:zaif_bid]
            if @asset[:zaif_btc] < amount
                return false
            else
                @asset[:zaif_jpy] += sellValue
                @asset[:zaif_btc] -= amount
            end
        end
        
        def buy_zaif_demo(amount)
             # 残JPY確認
            # 買い
            buyValue = amount * @value[:zaif_ask]
            if @asset[:zaif_jpy] < buyValue
                return false
            else
                @asset[:zaif_jpy] -= buyValue
                @asset[:zaif_btc] += amount
            end
            
            # 残BTC確認
            # 売り
            sellValue = amount * @value[:coincheck_bid]
            if @asset[:coincheck_btc] < amount
                return false
            else
                @asset[:coincheck_jpy] += sellValue
                @asset[:coincheck_btc] -= amount
            end
        end
        
        # 利益計算
        def profit
            profit = Profit.new(buy_coincheck: @value.zaif_bid - @value.coincheck_ask, buy_zaif: @value.coincheck_bid - @value.zaif_ask)
            profit.save
            @profit = profit
        end
        # 資金調整(JPY)
        def adjustAssetJpy
            # if(@asset[:coincheck_jpy] < @asset[:zaif_jpy])
            #     amount = ((@asset[:zaif_jpy] - @asset[:coincheck_jpy]) / 2).round
            #     @asset[:coincheck_jpy] += amount;
            #     @asset[:zaif_jpy] -= amount;
            # elsif(@asset[:zaif_jpy] < @asset[:coincheck_jpy])
            #     amount = ((@asset[:coincheck_jpy] - @asset[:zaif_jpy]) / 2).round
            #     @asset[:zaif_jpy] += amount;
            #     @asset[:coincheck_jpy] -= amount;
            # else
            #     false
            # end
        end
        
        # 資金調整(BTC)
        def adjustAssetBtc
            # if(@asset[:coincheck_btc] < @asset[:zaif_btc])
            #     amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
            #     @asset[:coincheck_btc] += amount;
            #     @asset[:zaif_btc] -= amount;
            # elsif(@asset[:zaif_btc] < @asset[:coincheck_btc])
            #     amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
            #     @asset[:zaif_btc] += amount;
            #     @asset[:coincheck_btc] -= amount;
            # else
            #     false
            # end
        end
        
        # zaif注文発行
        # type: "bid" or "ask" bidで買い askで売り
        # value: 注文価格
        # amount: 注文数量(最低0.0001)
        def zaifOrder(type, value, amount)
            begin
                if type == "buy"
                    ret = zaifApi.bid("btc", value, amount)
                elsif type == "sell"
                    ret = zaifApi.ask("btc", value, amount)
                end
            rescue APIErrorException => e
                # 資産移動の必要性が出たらここで行う
                p "zaifでの売買で問題が発生しました。"
                p e.message
            end
        end
        
        # coincheck注文発行
        # type: "bid" or "ask" bidで買い askで売り
        # value: 注文価格
        # amount: 注文数量(最低0.005)
        def coincheckOrder(type, value, amount)
            if type == "buy"
                ret = JSON.parse(@coincheckApi.create_orders(order_type: "buy", rate: value, amount: amount).body)
            elsif type == "sell"
                ret = JSON.parse(@coincheckApi.create_orders(order_type: "sell", rate: value, amount: amount).body)
            end
            
            if !ret["success"]
                p "coincheckでの売買で問題が発生しました。"
                p ret["error"]
            end
        end
        
        private
        
    end
end
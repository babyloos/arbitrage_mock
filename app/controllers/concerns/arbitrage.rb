
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
            @btcSendCost = 0.0005 # BTC送金手数料(BTC)
            @tradeAmount = 1 # １度に取引する数量(BTC)
            # 資産調整ごとに目標とする利益
            # 資産調整ごとに必要な利益(%)を手数料を加味して算出
            # 最高販売価格を元にBTC送金手数料の割合を算出
            # 最高販売価格を元にJPY送金手数料の割合を算出
            # 上記２つのうち高いほうを手数料とする
            bestBid = @value.coincheck_bid >= @value.zaif_bid ? @value.coincheck_bid : @value.zaif_bid
            adjustBtcFee = bestBid * @btcSendCost
            feePer = adjustBtcFee / bestBid * 100 # 資産調整ごとに必要な手数料の割合(%)
            @profitRequiredForOneAdjustAsset = feePer # 資産調整ごとに必要な利益(%)
            # puts "bestBid : " + bestBid.to_s
            # puts "adjustBtcFee : " + adjustBtcFee.to_s
            # puts "資産調整ごとに必要な利益 : " + @profitRequiredForOneAdjustAsset.to_s + "%"
            @profitRequiredForOneTransaction # １度の取引ごとに必要な利益
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
            begin
                zaifData = @zaifApi.get_ticker("btc")
            rescue ConnectionFailedException, Net::OpenTimeout => e
                puts "zaifへのアクセスに失敗したっぽいっす"
                puts "message : " + e.message
                puts "もういっかいだけ試してみるっす"
                sleep(1)
                begin
                    zaifData = @zaifApi.get_ticker("btc")
                rescue ConnectionFailedException => e
                    puts "やっぱだめだったっす、あきらめます"
                    exit
                end
                puts "いけたっす"
            end
            value = Value.new(coincheck_bid: coincheckData["bid"], coincheck_ask: coincheckData["ask"], zaif_bid: zaifData["bid"], zaif_ask: zaifData["ask"])
            value.save
            @value = Value.last
        end
        
        # 資産情報の更新
        def updateAsset
            if @production
                # coincheck
                coincheckAsset = JSON.parse(@coincheckApi.read_balance.body)
                # zaif
                zaifAsset = @zaifApi.get_info
                asset = Asset.new(coincheck_jpy: coincheckAsset["jpy"], coincheck_btc: coincheckAsset["btc"],
                                    zaif_jpy: zaifAsset["deposit"]["jpy"], zaif_btc: zaifAsset["deposit"]["btc"])
                asset.save
                asset
            else
                asset = Asset.new(coincheck_jpy: @asset[:coincheck_jpy], coincheck_btc: @asset[:coincheck_btc],
                                    zaif_jpy: @asset[:zaif_jpy], zaif_btc: @asset[:zaif_btc])
                asset.save
                asset
            end
        end
        
        # 本番取引
        def trade
            # 利益計算
            profit
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
            # 利益を利益率に変換して、一度の取引で必要な利益率と比べる
            buy_coincheck_profit_per = @profit[:buy_coincheck] / @value.zaif_bid * 100
            buy_zaif_profit_per = @profit[:buy_zaif] / @value.coincheck_bid * 100
            
            
            puts "コインチェックで買った場合の利益" + buy_coincheck_profit_per.to_s + "%"
            puts "ザイフで買った場合の利益" + buy_zaif_profit_per.to_s + "%"
            
            if buy_coincheck_profit_per > @profitRequiredForOneTransaction
                p "buy coincheck"
                buy_coincheck_demo(@tradeAmount)
            elsif buy_zaif_profit_per > @profitRequiredForOneTransaction
                p "buy zaif"
                buy_zaif_demo(@tradeAmount)
            else
                puts "利益が規定値以下のため取引は行われませんでした。"
            end
        end
        
        # coincheckで買ってzaifで売る
        def buy_coincheck_demo(amount)
            # 残JPY確認
            # 買い
            buyValue = amount * @value[:coincheck_ask]
            puts "購入に必要なJPY : " + buyValue.to_s
            if @asset[:coincheck_jpy] < buyValue
                return :need_jpy
            else
                @asset[:coincheck_jpy] -= buyValue
                @asset[:coincheck_btc] += amount
            end
            
            # 残BTC確認
            # 売り
            sellValue = amount * @value[:zaif_bid]
            puts "販売に必要なBTC : " + amount.to_s
            if @asset[:zaif_btc] < amount
                return :need_btc
            else
                @asset[:zaif_jpy] += sellValue
                @asset[:zaif_btc] -= amount
            end
        end
        
        def buy_zaif_demo(amount)
             # 残JPY確認
            # 買い
            buyValue = amount * @value[:zaif_ask]
            puts "購入に必要なJPY : " + buyValue.to_s
            if @asset[:zaif_jpy] < buyValue
                return :need_jpy
            else
                @asset[:zaif_jpy] -= buyValue
                @asset[:zaif_btc] += amount
            end
            
            # 残BTC確認
            # 売り
            sellValue = amount * @value[:coincheck_bid]
            puts "販売に必要なBTC : " + amount.to_s
            if @asset[:coincheck_btc] < amount
                return :need_btc
            else
                @asset[:coincheck_jpy] += sellValue
                @asset[:coincheck_btc] -= amount
            end
        end
        
        # 利益計算
        def profit
            profit = Profit.new(buy_coincheck: @value.zaif_bid - @value.coincheck_ask, buy_zaif: @value.coincheck_bid - @value.zaif_ask)
            profit.save
            
            # 利益をパーセンテージで表す
            # 現在の取引量を加味して利益を出しそのパーセンテージを生成する
            @profit = profit
            # 現在取引した場合の最大の利益
            bestProfit = [@profit.buy_coincheck, @profit.buy_zaif].sort[-1]
            # 現在の取引量で利益のパーセンテージを算出
            @profit.buy_coincheck *= @tradeAmount
            # 一番高い買い値を元に利益のパーセンテージを算出
            bestBid = [@value.coincheck_bid, @value.zaif_bid].sort[-1]
            profitPer = bestProfit / bestBid * 100
            puts @tradeAmount.to_s + "BTC取引した場合の利益 " + sprintf("%g", @profit.buy_coincheck) + "円(" + sprintf("%g", profitPer.round(10)) + "%)"
            
            # １回の取引に必要な利益（%）をセット
            
            available_trade_counts = []
            # 現在の資産を元に１回の取引で必要な利益を計算する
            # 現在の資産であと何回取引できるか（最少回数）
            # coincheck
            # 連続購入した場合
            available_trade_counts.push(@asset.coincheck_btc / @tradeAmount)
            # 連続販売した場合
            available_trade_counts.push(@asset.coincheck_jpy / (@value.coincheck_bid * @tradeAmount))
            # zaif
            # 連続購入した場合
            available_trade_counts.push(@asset.zaif_btc / @tradeAmount)
            # 連続販売した場合
            available_trade_counts.push(@asset.zaif_jpy / (@value.zaif_bid * @tradeAmount))
            
            # 最終的に一番少ない取引可能回数
            available_trade_count = available_trade_counts.sort[0].floor
            
            puts "現在の最少可能取引回数は " + available_trade_count.to_s + " です"
            if available_trade_count == 0
                # BTC、JPYのどちらを移動する必要があるのかの調査
                if (@asset.coincheck_btc / @tradeAmount) < 1 || (@asset.zaif_btc / @tradeAmount) < 1
                    # BTCの移動
                    puts "BTCの資産移動を行います"
                    adjustAssetBtc
                else
                    # JPYの移動
                    puts "JPYの資産移動を行います"
                    adjustAssetJpy
                end
            end
            
            # １回の取引ごとの最低必要利益を計算する
            @profitRequiredForOneTransaction = @profitRequiredForOneAdjustAsset / available_trade_count # １回の資産調整ごとに必要な利益(%)
            puts "１回の取引ごとの最低必要利益は " + @profitRequiredForOneTransaction.to_s + "(%)です"
        end
        
        # 資金調整デモ
        # 仮想的な資金移動
        # BTCのみ自動調整する
        # BTC送金手数料を加味する
        # 送金手数料0.0005BTC
        # adjust_type: :jpy or :btc
        def adjustAsset_demo(adjust_type = :btc)
            if(@asset[:coincheck_btc] < @asset[:zaif_btc])
                amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
                @asset[:zaif_btc] -= amount
                @asset[:zaif_btc] -= @btcSendCost; # BTC送金コストを引く
                @asset[:coincheck_btc] += amount;
            elsif(@asset[:coincheck_btc] > @asset[:zaif_btc])
                amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
                @asset[:coincheck_btc] -= amount
                @asset[:coincheck_btc] -= @btcSendCost; # BTC送金コストを引く
                @asset[:zaif_btc] += amount;
            else
                false
            end
        end 
        
        # 資金調整(JPY)デモ
        # 実際には手動で行うのでこれはデバッグ用
        # 外から使われるのでスタティックメソッドとする
        # 常に少ない方から多い方に移動する
        # amount: 移動するJPYの量 :autoなら両取引所で同じ金額になるようにする
        def self.adjustAssetJpy_demo(move_amount = :auto)
            
            # 資金移動手数料
            coincheckToZaifFee = 886
            zaifToCoincheckFee = 1106
            
            lastAsset = Asset.last
            asset = Asset.new(coincheck_jpy: lastAsset.coincheck_jpy, coincheck_btc: lastAsset.coincheck_btc, zaif_jpy: lastAsset.zaif_jpy, zaif_btc: lastAsset.zaif_btc)
            
            if asset.coincheck_jpy < asset.zaif_jpy
                # 移動量が自動の場合
                if move_amount == :auto
                    amount = (asset.zaif_jpy - asset.coincheck_jpy) / 2
                    asset.zaif_jpy -= amount
                    asset.zaif_jpy -= zaifToCoincheckFee # 手数料を引く
                    asset.coincheck_jpy += amount
                end
            elsif asset.coincheck_jpy > asset.zaif_jpy
                # 移動量が自動の場合
                if move_amount == :auto
                    amount = (asset.coincheck_jpy - asset.zaif_jpy) / 2
                    asset.coincheck_jpy -= amount
                    asset.coincheck_jpy -= coincheckToZaifFee # 手数料を引く
                    asset.zaif_jpy += amount 
                end
            end
            
            asset.save
        end
 
        # 資金調整(JPY)
        def adjustAssetJpy
            if(@asset[:coincheck_jpy] < @asset[:zaif_jpy])
                amount = ((@asset[:zaif_jpy] - @asset[:coincheck_jpy]) / 2).round
                @asset[:coincheck_jpy] += amount;
                @asset[:zaif_jpy] -= amount;
                
                updateAsset
            elsif(@asset[:zaif_jpy] < @asset[:coincheck_jpy])
                amount = ((@asset[:coincheck_jpy] - @asset[:zaif_jpy]) / 2).round
                @asset[:zaif_jpy] += amount;
                @asset[:coincheck_jpy] -= amount;
                
                updateAsset
            else
                false
            end
        end
        
        # 資金調整(BTC)
        def adjustAssetBtc
            if(@asset[:coincheck_btc] < @asset[:zaif_btc])
                amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
                @asset[:coincheck_btc] += amount;
                @asset[:zaif_btc] -= amount;
                
                updateAsset
            elsif(@asset[:zaif_btc] < @asset[:coincheck_btc])
                amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
                @asset[:zaif_btc] += amount;
                @asset[:coincheck_btc] -= amount;
                
                updateAsset
            else
                false
            end
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

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
            @value = nil
            @btcSendFee = 0.0005 # BTC送金手数料(BTC)
            @tradeAmount = 0.1 # １度に取引する数量(BTC)
            @asset = Asset.last
            @profit;
            @requiredProfitForEachTransaction = 0.001 # １回の取引ごとに必要な利益(%)
        end
        
        # 価格情報の更新
        def updateValue
            # coincheckDepthの取得
            coincheckDepth = JSON.parse(@coincheckApi.read_order_books.body)
            # zaifDepthの取得
            zaifDepth = @zaifApi.get_depth("btc")
            
            # 利益計算し取得
            # @profit = profitWithAmount(coincheckDepth, zaifDepth)
            @profit = profitWidthDesignationAmount(coincheckDepth, zaifDepth, @tradeAmount)
            profit = Profit.new(profit: @profit[:profit], amount: @profit[:amount], order: @profit[:order], per1BtcProfit: @profit[:per1BtcProfit])
            profit.save
        
            value = Value.new(coincheck_bid: coincheckDepth["bids"].first[0], coincheck_ask: coincheckDepth["asks"].first[0], zaif_bid:  zaifDepth["bids"].first[0], zaif_ask: zaifDepth["asks"].first[0])
            value.save
            @value = value
        end
        
        # 資産情報の更新
        # 資産情報をDBに保存
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
        
        # 裁定取引
        def trade
            if @production
                production_trade
            else
                demoTrade
            end
        end
        
         # デモ取引
        def demoTrade
            
            # puts "コインチェックで買った場合の利益" + buy_coincheck_profit_per.to_s + "%"
            # puts "ザイフで買った場合の利益" + buy_zaif_profit_per.to_s + "%"
            
            # １回の取引に必要な利益を計算する
            
            if @profit[:order] == "buy_coincheck"
                # 利率を計算し比較する
                profitPer = @profit[:profit] / @profit[:amount] / @value.coincheck_ask * 100
                puts @profit[:amount].to_s + "BTCをコインチェックで買いザイフで売った場合の利益 : " + @profit[:profit].to_s + " 利益率 : " + profitPer.to_s
                # 利益が規定値以上だった場合実際の取引を行う
                if profitPer > @requiredProfitForEachTransaction
                    ret = buy_coincheck_demo(@profit[:amount], @value.coincheck_ask, @value.zaif_bid)
                    if ret == :need_jpy
                        puts "JPYが足りません。資金調整が必要です。"
                    elsif ret == :need_btc
                        puts "BTCが足りません。資金調整が必要です。"
                    else
                        puts @profit[:amount].to_s + "BTCをコインチェックで買ってザイフで売り" + @profit[:profit].to_s + "円の粗利が出ました"
                    end
                end
            elsif @profit[:order] == "buy_zaif"
                # 利率を計算し比較する
                profitPer = @profit[:profit] / @profit[:amount] / @value.zaif_ask * 100
                puts @profit[:amount].to_s + "BTCをザイフで買いコインチェックで売った場合の利益 : " + @profit[:profit].to_s + " 利益率 : " + profitPer.to_s
                # 利益が規定値以上だった場合実際の取引を行う
                if profitPer > @requiredProfitForEachTransaction
                    ret = buy_zaif_demo(@profit[:amount], @value.zaif_ask, @value.coincheck_bid)
                    if ret == :need_jpy
                        puts "JPYが足りません。資金調整が必要です。"
                    elsif ret == :need_btc
                        puts "BTCが足りません。資金調整が必要です。"
                    else
                        puts @profit[:amount].to_s + "BTCをザイフで買ってコインチェックで売り" + @profit[:profit].to_s + "円の粗利が出ました"
                    end
                end
            end
            
        end
        
        # coincheckで買ってzaifで売る
        # 資産が足りなければ調整する
        def buy_coincheck_demo(amount, buyValue, sellValue)
            # 実際に売買する前に売買するだけの資金があるかチェックする
            if @asset[:coincheck_jpy] < buyValue * amount
                return :need_jpy
            elsif @asset[:zaif_btc] < amount
                return :need_btc
            end
            
            # 買い
            @asset[:coincheck_jpy] -= buyValue * amount
            @asset[:coincheck_btc] += amount
            
            # 売り
            @asset[:zaif_jpy] += sellValue * amount
            @asset[:zaif_btc] -= amount
            
            updateAsset
            true
        end
        
        def buy_zaif_demo(amount, buyValue, sellValue)
            # 実際に売買する前に売買するだけの資金があるかチェックする
            if @asset[:zaif_jpy] < sellValue * amount
                return :need_jpy
            elsif @asset[:coincheck_btc] < amount
                return :need_btc
            end
            
            # 買い
            @asset[:zaif_jpy] -= buyValue * amount
            @asset[:zaif_btc] += amount
            
            # 売り
            @asset[:coincheck_jpy] += sellValue * amount
            @asset[:coincheck_btc] -= amount
            
            updateAsset
            true
        end
        
        # 資金調整デモ
        # BTC送金手数料を加味する
        # 送金手数料0.0005BTC
        # adjust_type: :jpy or :btc
        def adjustAsset_demo(adjust_type = :btc)
            if(@asset[:coincheck_btc] < @asset[:zaif_btc])
                amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
                @asset[:zaif_btc] -= amount
                @asset[:zaif_btc] -= @btcSendFee; # BTC送金コストを引く
                @asset[:coincheck_btc] += amount;
            elsif(@asset[:coincheck_btc] > @asset[:zaif_btc])
                amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
                @asset[:coincheck_btc] -= amount
                @asset[:coincheck_btc] -= @btcSendFee; # BTC送金コストを引く
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
        # def adjustAssetJpy
        # end
 
        # 資金調整(BTC)
        # def adjustAssetBtc
        # end
        
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
                puts "zaifでの売買で問題が発生しました。"
                puts e.message
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
                puts "coincheckでの売買で問題が発生しました。"
                puts ret["error"]
            end
        end
        
        # debug
        # private
        
        # 現在の資産情報を元に１回に必要な利益を計算する
        # asset: 資産情報
        # adjustFee: 資産調整ごとに支払う手数料
        def calcNeedProfit(asset, adjustFee)
        end
        
        # amountを考慮して裁定取引利益を計算する
        # 実際に取引可能な数量を考慮し利益を計算する
        # 両取引所のbestBid, bestAskの価格、数量を元に計算する
        # return {profit: xxx, amount: yyy, order: "buy_coincheck" or "buy_zaif", per1BtcProfit: xxx}
        def profitWithAmount(coincheckDepth, zaifDepth)
            # 利益の計算
            coincheckBestBid = coincheckDepth["bids"].first
            coincheckBestAsk = coincheckDepth["asks"].first
            zaifBestBid = zaifDepth["bids"].first
            zaifBestAsk = zaifDepth["asks"].first
            
            # 最少取引可能量
            buy_coincheck_amount = [zaifBestBid[1].to_f, coincheckBestAsk[1].to_f].min
            buy_zaif_amount = [coincheckBestBid[1].to_f, zaifBestAsk[1].to_f].min
            # 最終的な最少取引可能量
            minAmount = nil
            # 発行オーダー
            order = nil
            
            buy_coincheck_profit = (zaifBestBid[0].to_f - coincheckBestAsk[0].to_f) * buy_coincheck_amount
            buy_zaif_profit = (coincheckBestBid[0].to_f - zaifBestAsk[0].to_f) * buy_zaif_amount
            if buy_coincheck_profit >= buy_zaif_profit
                bestProfit = buy_coincheck_profit
                minAmount = buy_coincheck_amount
                order = "buy_coincheck"
            else
                bestProfit = buy_zaif_profit
                minAmount = buy_zaif_amount
                order = "buy_zaif"
            end
            
            return {profit: bestProfit, amount: minAmount, order: order, per1BtcProfit: bestProfit/minAmount}
        end
        
        # 取引する数量を指定して裁定取引利益を計算する
        def profitWidthDesignationAmount(coincheckDepth, zaifDepth, amount)
            coincheckValue = calcTradeValueSum(coincheckDepth, amount)
            zaifValue = calcTradeValueSum(zaifDepth, amount)
            buy_coincheck_profit = zaifValue[:sell] - coincheckValue[:buy]
            buy_zaif_profit = coincheckValue[:sell] - zaifValue[:buy]
            if buy_coincheck_profit >= buy_zaif_profit
                bestProfit = buy_coincheck_profit
                order = "buy_coincheck"
            else
                bestProfit = buy_zaif_profit
                order = "buy_zaif"
            end
            
            return {profit: bestProfit, amount: amount, order: order, per1BtcProfit: bestProfit/amount}
        end
        
        # 板情報と数量を受け取り取引した場合の合計取引価格を計算する
        def calcTradeValueSum(depth, amount)
            ret = {buy: 0, sell: 0}
            # 購入価格
            sumAmount = 0
            sumValue = 0
            depth["asks"].each do |d|
                # 取引量が指定数量から出ないように
                # まるまる取引出来る場合
                if sumAmount != amount
                    if sumAmount + d[1].to_f <= amount
                        sumAmount += d[1].to_f
                        sumValue += d[0].to_f * d[1].to_f
                    # まるまるいれると超えちゃう場合
                    else
                        remaindAddAmount = amount - sumAmount
                        sumAmount += remaindAddAmount # これですっぽり入る
                        sumValue += d[0].to_f * remaindAddAmount
                    end
                end
            end
            ret[:buy] = sumValue
            
            # 販売価格
            sumAmount = 0
            sumValue = 0
            depth["bids"].each do |d|
                # 取引量が指定数量から出ないように
                # まるまる取引出来る場合
                if sumAmount != amount
                    if sumAmount + d[1].to_f <= amount
                        sumAmount += d[1].to_f
                        sumValue += d[0].to_f * d[1].to_f
                    # まるまるいれると超えちゃう場合
                    else
                        remaindAddAmount = amount - sumAmount
                        sumAmount += remaindAddAmount # これですっぽり入る
                        sumValue += d[0].to_f * remaindAddAmount
                    end
                end
            end
            ret[:sell] = sumValue
            
            ret
        end
    end
end
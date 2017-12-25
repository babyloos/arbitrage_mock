
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
            @requiredProfitForEachTransaction = nil # １回の取引ごとに必要な利益(%)
        end
        
        # 価格情報の更新
        def updateValue
            # coincheckDepthの取得
            coincheckDepth = JSON.parse(@coincheckApi.read_order_books.body)
            # zaifDepthの取得
            zaifDepth = @zaifApi.get_depth("btc")
            
            
            
            # 必要利益を計算する
            
            # 利益計算し取得
            # @profit = profitWithAmount(coincheckDepth, zaifDepth) # bestAsk, bestBidの価格のみを使って取引する
            @profit = profitWidthDesignationAmount(coincheckDepth, zaifDepth, @tradeAmount) # 固定数量を使って取引する
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
        def adjustAsset_demo(adjust_type)
            if adjust_type == :btc
                if(@asset[:coincheck_btc] < @asset[:zaif_btc])
                    amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
                    @asset[:zaif_btc] -= amount
                    @asset[:zaif_btc] -= @btcSendFee; # BTC送金コストを引く
                    @asset[:coincheck_btc] += amount;
                    saveAdjustAssetLog("coincheck", "btc", amount) 
                elsif(@asset[:coincheck_btc] > @asset[:zaif_btc])
                    amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
                    @asset[:coincheck_btc] -= amount
                    @asset[:coincheck_btc] -= @btcSendFee; # BTC送金コストを引く
                    @asset[:zaif_btc] += amount;
                    saveAdjustAssetLog("zaif", "btc", amount)
                else
                    false
                end
            elsif adjust_type == :jpy
                if(@asset[:coincheck_jpy] < @asset[:zaif_jpy])
                    amount = (@asset[:zaif_jpy] - @asset[:coincheck_jpy]) / 2
                    @asset[:zaif_jpy] -= amount
                    @asset[:zaif_jpy] -= @jpySendFee; # jpy送金コストを引く
                    @asset[:coincheck_jpy] += amount;
                    saveAdjustAssetLog("coincheck", "jpy", amount)
                elsif(@asset[:coincheck_jpy] > @asset[:zaif_jpy])
                    amount = (@asset[:coincheck_jpy] - @asset[:zaif_jpy]) / 2
                    @asset[:coincheck_jpy] -= amount
                    @asset[:coincheck_jpy] -= @jpySendFee; # jpy送金コストを引く
                    @asset[:zaif_jpy] += amount;
                    saveAdjustAssetLog("zaif", "jpy", amount)
                else
                    false
                end
            end
            adjustLog = AdjustLog.new()
            adjustLog.toExchanges = toExchanges
            adjustLog.type = type
            adjustLog.amount = amount
            adjustLog.save
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
        
        # 現在の資産情報を元に１回に必要な利率を計算する
        # 損失が出ないところを最低ラインとして利率を設定する
        # asset: 資産情報
        # adjustFee: 資産調整ごとに支払う手数料
        def calcNeedProfit(asset, value, adjustJpyFee, amount)
            available_trade_count = calcAvailableTradeCount(asset, value, amount)[:count]
            need_possibility_asset_type = calcAvailableTradeCount(asset, value, amount)[:needAsset]
            
            # 取引可能回数が１回を割っていたら資金調整を行う
            if available_trade_count < 1
                if need_possibility_asset_type == "jpy"
                    # JPYを資産調整
                    adjustAsset_demo(:jpy)
                    puts "JPYを調整しました。"
                elsif need_possibility_asset_type == "btc"
                    # BTCを資産調整
                    puts "BTCを調整しました。"
                    adjustAsset_demo(:btc)
                end
            end
            
            bestAsk = value.coincheck_ask <= value.coincheck_ask ? value.coincheck_ask : value.zaif_ask
            # 手数料のパーセンテージ
            # BTC送金手数料とJPY送金手数料の高い方を手数料とする
            # adjustFee = adjustJpyFee.to_f >= @btcSendFee.to_f * bestAsk.to_f ? adjustJpyFee.to_f : @btcSendFee * bestAsk.to_f
            adjustFee = (@zaifToCoincheckFee + @coincheckToZaifFee) + @btcSendFee.to_f * bestAsk.to_f 
            adjustFeePer = adjustFee / bestAsk * 100
            # １回の取引で必要な利率
            requiredProfit = adjustFeePer / available_trade_count
            
            # debug
            puts "bestAsk : " + bestAsk.to_s
            puts "adjustFee : " + adjustFee.to_s
            puts "最小取引可能回数 : " + available_trade_count.to_s
            puts "手数料のパーセンテージ : " + adjustFeePer.to_s + "%"
            requiredProfit = adjustFeePer / available_trade_count
            
            # debug
            puts "bestAsk : " + bestAsk.to_s
            puts "adjustFee : " + adjustFee.to_s
            puts "最小取引可能回数 : " + available_trade_count.to_s
            puts "手数料のパーセンテージ : " + adjustFeePer.to_s + "%"
            puts "１回の取引に必要な利益 ： " + requiredProfit.to_s + "%"
            requiredProfit
        end
        # 最少取引可能回数を返す
        def calcAvailableTradeCount(asset, value, amount)
             # 最低取引可能回数
             available_trade_counts = []
            # coincheck
            # 連続購入した場合
            available_trade_counts.push([asset.coincheck_btc / amount, "btc"])
            # 連続販売した場合
            available_trade_counts.push([asset.coincheck_jpy / (value.coincheck_bid * amount), "jpy"])
            # zaif
            # 連続購入した場合
            available_trade_counts.push([asset.zaif_btc / amount, "btc"])
            # 連続販売した場合
            available_trade_counts.push([asset.zaif_jpy / (value.zaif_bid * amount), "jpy"])
            # 最終的に一番少ない取引可能回数
            # available_trade_count = available_trade_counts.sort[0]
            minTradeCount = 999999
            needPossibilityAsset = ""
            available_trade_counts.each do |c|
                if minTradeCount > c[0]
                    minTradeCount = c[0]
                    needPossibilityAsset = c[1]
                end
            end
            
            # 最少取引可能回数
            available_trade_count = minTradeCount
            # 最少取引を行うときに足りなくなる可能性のある資産 jpy or btc
            need_possibility_asset = needPossibilityAsset
            
            return {count: minTradeCount, needAsset: need_possibility_asset}
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
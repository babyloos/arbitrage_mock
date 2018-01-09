=begin

    裁定取引を行うモック
        
=end

module ArbitrageMock
    extend ActiveSupport::Concern # インスタンスメソッドのみの利用時は記述の必要なし
    require 'csv'
    require 'date'
    require 'kaesen'

    class ArbitrageMock
    	
    	attr_accessor :value, :asset
    
        def initialize(asset)
    		@bitflyer =  Kaesen::Bitflyer.new
    		@coincheck = Kaesen::Coincheck.new
    		@btcbox = Kaesen::Btcbox.new
    		@zaif = Kaesen::Zaif.new
    	
    		# 初期合計BTC量
    		@initSumBtcAmount = asset[:coincheck_btc] + asset[:zaif_btc]
    	
    		# 初期合計JPY量
    		@initSumJpyAmount = asset[:coincheck_jpy] + asset[:zaif_jpy]
    	
    	    @coincheckJpyToZaifFee = 886.0
    	    @zaifJpyToCoincheckFee = 1106.0
    # 		@btcSendFee = 0.0005
    		@coincheckBtcToZaifFee = 0.001
    		@zaifBtcToCoincheckFee = 0.0001
    		
    		
    		# 資産調整時点のJPY総額
    		@adjustSumJpyAmount = @initSumJpyAmount
    	
    		# 最小取引可能数量
    		@minTradeAmount = 0.005
    	
    		@asset = asset
    	
    		# csvログ用
    		@csvFile = CSV.open("arbitrage_log.csv", 'w')
        end
        
        # 金額を指定してBTC数量を得る
        # exchanges: "coincheck" or "zaif"
        # buyValue: 購入金額
        
    
        def debug
    		while true do
    		    ret = getDepth
    		    getValue
    		    ret = true
    		    if !ret
    				next
    		    end
    		    
    		    # 最小取引可能回数更新
    		    @tradeCount = calcTradeCount
    		    # 現在の取引量
    			profit = calcProfit(@minTradeAmount)
    		    # tradeAmount = calcOnceTradeAmount(profit[:order])
    		    printf("現在の取引量 : %f\n", @minTradeAmount)
    			printf("現在の取引可能回数 : %f\n", @tradeCount)
    			printf("現在差額(1BTCあたり) : %f\n", profit[:profit] / @minTradeAmount)
    			printf("現在差額(取引量あたり) : %f\n", profit[:profit])
    			printf("1BTCあたりの必要差額 : %f\n", calcNeedProfitAtOneTrade.to_f / @minTradeAmount)
    		    printf("１取引あたりの必要利益 : %f\n", calcNeedProfitAtOneTrade.to_f)
    		    printf("現在の数量での利益(%sで購入) : %f\n", profit[:order], profit[:profit])
    		    
    		    tradeInfo = {
    		        amount: @minTradeAmount,
    		        count: @tradeCount,
    		        profit1btc: calcProfit(1)[:profit],
    		        profitAmount: profit[:profit],
    		        needProfit1btc: calcNeedProfitAtOneTrade.to_f / @minTradeAmount,
    		        needProfitAmount: calcNeedProfitAtOneTrade.to_f,
    		        order: profit[:order],
    		        trade: false
    		    }
    		    
    		    tradeRet = trade
    		    # 資産調整を確認
    		    checkAvailableAdjustAsset
    		    if tradeRet
    				puts "取引しました"
    				order = tradeRet[:order]
    				# amount = calcOnceTradeAmount(tradeRet[:order])
    				amount = @minTradeAmount
    				# puts "現在の利益 : " + tradeRet[:profit].to_s
    				# profit = tradeRet[:profit] * calcOnceTradeAmount(tradeRet[:order])
    				profit = tradeRet[:profit] * @minTradeAmount
    				tradeInfo[:trade] = true
    		    else
    				puts "取引しませんでした"
    				order = "none"
    				amount = 0
    				profit = 0
    		    end
    	
    		    # JPYに損益が出たら異常なのでとめる
    		    if @initSumJpyAmount > (@asset[:coincheck_jpy] + @asset[:zaif_jpy])
    		        puts "異常が発生しました。JPYがマイナスになりました。"
    		        printf("総JPY資産 : %f, coincheckJPY : %f, zaifJPY : %f\n", (@asset[:coincheck_jpy] + @asset[:zaif_jpy]), @asset[:coincheck_jpy], @asset[:zaif_jpy])
    		        exit()
    		    end
    	
    		    # ログ出力
    		    if order == "buy_coincheck"
    				order = "コインチェックで買いザイフで売る"
    		    elsif order == "buy_zaif"
    				order = "ザイフで買いコインチェックで売る"
    		    else
    				order = "取引無し"
    		    end
    		    data = {
    				includeAsset: calcIncludeAsset.to_f.round(5),
    				totalJpy: (@asset[:coincheck_jpy] + @asset[:zaif_jpy]).to_f.round(5),
    				totalBtc: (@asset[:coincheck_btc] + @asset[:zaif_btc]).to_f.round(5),
    				coincheckJpy: @asset[:coincheck_jpy].to_f.round(5),
    				coincheckBtc: @asset[:coincheck_btc].to_f.round(5),
    				zaifJpy: @asset[:zaif_jpy].to_f.round(5),
    				zaifBtc: @asset[:zaif_btc].to_f.round(5),
    				order: order,
    				amount: amount.to_f.round(5),
    				profit: profit.to_f.round(5)
    		    }
    		  #  writeLog(data)
    		    p data
    		    
    		    # DBに各情報を保存
    		    saveValue(@value)
    		    saveAsset(@asset)
    		    saveProfit
    		    saveInfo(tradeInfo)
    		    
    		    sleep(1)
    		end
        end
    
        # ログ出力
        # data: {totalJpy: 10000000, totalBtc: 1, includeAsset: 3000000, coincheckJpy: 500000, coincheckBtc: 0.5, zaifJpy: 500000, zaifBtc: 0.5, order: "buy_coincheck" or "buy_zaif", amount: 0.05, profit: 1000}
        def writeLog(data)
    		@csvFile.puts [
    		    printf("%f", data[:totalJpy]),
    		    printf("%f", data[:totalBtc]),
    		    data[:includeAsset],
    		    data[:coincheckJpy],
    		    data[:coincheckBtc],
    		    data[:zaifJpy],
    		    data[:zaifBtc],
    		    data[:order],
    		    data[:amount],
    		    data[:profit],
    		    Time.now.strftime("%Y-%m-%d %H:%M:%S")
    		]
        end
        
        private
        
        # 資産情報をDBに保存
        def saveAsset(asset)
            # 内容が変更されている場合のみ更新する
            lastAsset = Asset.last
            if lastAsset.coincheck_jpy != asset[:coincheck_jpy] || lastAsset.coincheck_btc != asset[:coincheck_btc] || lastAsset.zaif_jpy != asset[:zaif_jpy] || lastAsset.zaif_btc != asset[:zaif_btc]
                a = Asset.new(coincheck_jpy: asset[:coincheck_jpy], coincheck_btc: asset[:coincheck_btc], zaif_jpy: asset[:zaif_jpy], zaif_btc: asset[:zaif_btc])
                a.save
            end
        end
        
        # 価格情報をDBに保存
        def saveValue(value)
            v = Value.new(coincheck_bid: value[:coincheck]["bid"], coincheck_ask: value[:coincheck]["ask"], zaif_bid: value[:zaif]["bid"], zaif_ask: value[:zaif]["ask"])
            v.save
        end
        
        # 利益情報をDBに保存
        def saveProfit
            profit = calcProfit(@minTradeAmount)
            profit = Profit.new(profit: profit[:profit], amount: @minTradeAmount, order: profit[:order], per1BtcProfit: calcProfit(1)[:profit])
            profit.save
        end
        
        # 取引情報をDBに保存
        def saveInfo(info)
            i = TradeInfo.new(info)
            i.save
        end
        
        # 前回の資産調整時点より資産調整コスト分最低でも合計JPY資産が増えていたら資産調整を行う
        def checkAvailableAdjustAsset
            sumAssetJpy = @asset[:coincheck_jpy] + @asset[:zaif_jpy]
            p "sumAssetJpy : " + sumAssetJpy.to_s
            p "adjustSumJpyAmount : " + @adjustSumJpyAmount.to_s
            p "calcTotalFee : " + calcTotalFee.to_s
            
            if @adjustSumJpyAmount + calcTotalFee <= sumAssetJpy
                # 資産調整
                adjustAsset("jpy")
                adjustAsset("btc")
                
                @adjustSumJpyAmount = sumAssetJpy
            end
        end
    
        # 取引を行う 
        def trade
    		# 利益が１回の取引に必要な利益以上だった場合取引を行う
    		# 利益計算
    		profit = calcProfit(@minTradeAmount)
    	 	needProfit = calcNeedProfitAtOneTrade
    		# if profit[:profit] * calcOnceTradeAmount(profit[:order]) >= needProfit
    		if profit[:profit] >= needProfit # 取引数量を固定化
    		    # order(profit[:order], calcOnceTradeAmount(profit[:order]))
    		    order(profit[:order], @minTradeAmount) # 取引数量を固定化
    		    profit
    		else
    		    false
    		end
        end
    
        # コインの売買を行う
        # type: "buy_coincheck" or "buy_zaif"
        # amount: 0.005
        def order(type, amount)
    		if type == "buy_coincheck"
    		    buy_coincheck(amount)
    		elsif type == "buy_zaif"
    		    buy_zaif(amount)
    		end
        end
    
        # コインを買う
        # exchanges: "coincheck" or "zaif"
        # amount: 0.05
        def buy_btc(exchanges, amount)
    		if exchanges == "coincheck"
    		    @asset[:coincheck_jpy] -= calcTradeValueSum(@depth[:coincheck], amount)[:buy]
    		    @asset[:coincheck_btc] += amount
    		elsif exchanges == "zaif"
    		    @asset[:zaif_jpy] -= calcTradeValueSum(@depth[:zaif], amount)[:buy]
    		    @asset[:zaif_btc] += amount
    		end
        end
    
        # コインチェックで買ってザイフで売る
        def buy_coincheck(amount)
    		jpyAdjustFee = calcJpySendFee("coincheck")
    		btcFee = calcBtcSendFee
    		
    		coincheck_sum_value = calcTradeValueSum(@depth[:coincheck], amount)
    		@asset[:coincheck_jpy] -= coincheck_sum_value[:buy]
    		@asset[:coincheck_btc] += amount
    		zaif_sum_value = calcTradeValueSum(@depth[:zaif], amount)

    		@asset[:zaif_jpy] += zaif_sum_value[:sell]
    		@asset[:zaif_btc] -= amount
        end
    
        # ザイフで買ってコインチェックで売る
        def buy_zaif(amount)
    		jpyAdjustFee = calcJpySendFee("zaif")
    		btcFee = calcBtcSendFee
    		
    		zaif_sum_value = calcTradeValueSum(@depth[:zaif], amount)
    		@asset[:zaif_jpy] -= zaif_sum_value[:buy]
    		@asset[:zaif_btc] += amount
    		
    		coincheck_sum_value = calcTradeValueSum(@depth[:coincheck], amount)
    		@asset[:coincheck_jpy] += coincheck_sum_value[:sell]
    		@asset[:coincheck_btc] -= amount
        end
    
        # １回の取引に必要な１ビットコインあたりの利益計算
        def calcNeedProfitAtOneTrade
    		calcTotalFee / @tradeCount
        end
    
        # １回に取引する量を計算する
        # order: "buy_coincheck" or "buy_zaif"
    #     def calcOnceTradeAmount(order)
    # 		# 最小取引数量を考慮
    # 		# 0.005
    # 		if order == "buy_coincheck"
    # 		    availableTradeAmount = [@asset[:coincheck_jpy] / @value[:coincheck]["bid"] / @tradeCount, @asset[:zaif_btc] / @tradeCount].min
    # 		    if availableTradeAmount < @minTradeAmount
    # 				puts "取引出来る数量が下限(0.005BTC)を下回りました。" + availableTradeAmount.to_s
    # 				# debug
    # 				@minTradeAmount
    # 		    else
    # 				availableTradeAmount
    # 		    end
    # 		elsif order == "buy_zaif"
    # 		    availableTradeAmount = [@asset[:zaif_jpy] / @value[:zaif]["bid"] / @tradeCount, @asset[:coincheck_btc] / @tradeCount].min
    # 		    if availableTradeAmount < @minTradeAmount
    # 				puts "取引出来る数量が下限(0.005BTC)を下回りました。" + availableTradeAmount.to_s
    # 				# puts "取引出来る数量が下限(0.005BTC)を下回りました。"
    # 				# debug
    # 				@minTradeAmount
    # 		    else
    # 				availableTradeAmount
    # 		    end
    # 		end
    #     end
        
        # 何回取引出来るかを計算する
        def calcTradeCount
        	buy_coincheck = @asset[:coincheck_jpy] / (@minTradeAmount * @value[:coincheck]["ask"])
        # 	buy_zaif = @asset[:zaif_jpy] / (@minTradeAmount * @value[:zaif]["ask"])
        # 	[buy_coincheck, buy_zaif].min
            buy_coincheck
        end
    
        # 1BTCあたりの裁定利益計算
      #  def calcProfit
    		# buy_coincheck = @value[:zaif]["bid"] - @value[:coincheck]["ask"]
    		# buy_zaif = @value[:coincheck]["bid"] - @value[:zaif]["ask"]
    		# if buy_coincheck > buy_zaif
    		#     order = "buy_coincheck"
    		#     profit = buy_coincheck
    		# else
    		#     order = "buy_zaif"
    		#     profit = buy_zaif
    		# end
    		# ret = {order: order, profit: profit}
      #  end
      
        # 板情報を考慮した裁定利益計算
        # amount: 取引数量
        def calcProfit(amount)
        	profit = profitWidthDesignationAmount(@depth[:coincheck], @depth[:zaif], amount)
        	{order: profit[:order], profit: profit[:profit]}
        end
        
        # 板情報を考慮した裁定利益計算
        # amount: 取引数量
        def calcProfit(amount)
        	profit = profitWidthDesignationAmount(@depth[:coincheck], @depth[:zaif], amount)
        	{order: profit[:order], profit: profit[:profit]}
        end
        
        # 板情報取得
        def getDepth
        	begin
    		    # bitflyerTicker = @bitflyer.ticker
    		    coincheckDepth = @coincheck.depth
    		    # btcboxTicker = @btcbox.ticker
    		    zaifDepth = @zaif.depth
    		rescue Kaesen::Market::ConnectionFailedException => e
    		   puts e.message
    		   return false
    		rescue Net::OpenTimeout => e
    		    puts e.message
    		    return false;
    		end
    		
    		@depth = {coincheck: coincheckDepth, zaif: zaifDepth}
    	end
    
        # 価格取得
        def getValue
    		# begin
    		#     bitflyerTicker = @bitflyer.ticker
    		#     coincheckTicker = @coincheck.ticker
    		#     btcboxTicker = @btcbox.ticker
    		#     zaifTicker = @zaif.ticker
    		# rescue Kaesen::Market::ConnectionFailedException => e
    		#   puts e.message
    		#   return false
    		# end
    	
    		# @value = {coincheck: coincheckTicker, zaif: zaifTicker}
    		# debug
    		# coincheck = {"bid"=>2000000, "ask"=>2001000}
    		# zaif = {"bid"=>2010000 , "ask"=>2005000}
    		# @value = {coincheck: coincheck, zaif: zaif}
    		
    		@value = {
    			coincheck: { 
    				"bid" => @depth[:coincheck]["bids"][0][0],
    				"ask" => @depth[:coincheck]["asks"][0][0]
    			},
    			zaif: {
    				"bid" => @depth[:zaif]["bids"][0][0],
    				"ask" => @depth[:zaif]["asks"][0][0]
    			}
    		}
        end
    
        # 資産調整
        # type: "btc" or "jpy"
        def adjustAsset(type)
    		if type == "btc"	
    		    if @asset[:coincheck_btc] < @asset[:zaif_btc]
    				amount = (@asset[:zaif_btc] - @asset[:coincheck_btc]) / 2
    				@asset[:zaif_btc] -= amount + @zaifBtcToCoincheckFee
    				@asset[:coincheck_btc] += amount
    	
    				# BTCを補充する
    				replenAmount = @initSumBtcAmount - (@asset[:coincheck_btc] + @asset[:zaif_btc])
    				replenBtc(replenAmount)
    		    elsif @asset[:coincheck_btc] > @asset[:zaif_btc]
    				amount = (@asset[:coincheck_btc] - @asset[:zaif_btc]) / 2
    				@asset[:coincheck_btc] -= amount + @coincheckBtcToZaifFee
    				@asset[:zaif_btc] += amount
    	
    		    	# BTCを補充する
    				replenAmount = @initSumBtcAmount - (@asset[:coincheck_btc] + @asset[:zaif_btc])
    				replenBtc(replenAmount)
    		    else
    				false
    		    end
    		elsif type == "jpy"	
    		    if @asset[:coincheck_jpy] < @asset[:zaif_jpy]
    				amount = (@asset[:zaif_jpy] - @asset[:coincheck_jpy]) / 2
    				@asset[:zaif_jpy] -= amount + calcJpySendFee("coincheck")
    				@asset[:coincheck_jpy] += amount
    		    elsif @asset[:coincheck_jpy] > @asset[:zaif_jpy]
    				amount = (@asset[:coincheck_jpy] - @asset[:zaif_jpy]) / 2
    				@asset[:coincheck_jpy] -= amount + calcJpySendFee("zaif")
    				@asset[:zaif_jpy] += amount
    		    else
    				false
    		    end
    		end
        end
    
        # 含み総資産を計算
        def calcIncludeAsset
    		totalBtcToJpy = @asset[:coincheck_btc] * @value[:coincheck]["bid"] + @asset[:zaif_btc] * @value[:zaif]["bid"]
    		totalJpy = @asset[:coincheck_jpy] + @asset[:zaif_jpy]
    		totalJpy + totalBtcToJpy
        end
    
        # BTCを補充する
        def replenBtc(amount)
    		# 安い方に補充する
    		bestAsk = @value[:coincheck]["ask"] <= @value[:zaif]["ask"] ? {ask: @value[:coincheck]["ask"], order: "coincheck"} : {ask: @value[:zaif]["ask"], order: "zaif"}
    		buy_btc(bestAsk[:order], amount)
        end
    
        # 資産が１回転したときの合計手数料算出
        def calcTotalFee
    		# 高いほうに統一
    		@zaifJpyToCoincheckFee + calcBtcSendFee
        end
    
        # 現在のビットコイン送金手数料算出
        # 高いほうの手数料を考慮
        def calcBtcSendFee
        	btcFee = @coincheckBtcToZaifFee > @zaifBtcToCoincheckFee ? @coincheckBtcToZaifFee : @zaifBtcToCoincheckFee
    		jpyFee = getBestAsk * btcFee
    		jpyFee
        end
    
        # 日本円送金手数料算出
        # to: "coincheck" or "zaif"
        def calcJpySendFee(to)
    		if to == "coincheck"
    		    @zaifJpyToCoincheckFee
    		elsif to == "zaif"
    		    @coincheckJpyToZaifFee
    		end
        end
    
        # 最低購入価格
        def getBestAsk
    		@value[:coincheck]["ask"] <= @value[:zaif]["ask"] ? @value[:coincheck]["ask"] : @value[:zaif]["ask"]
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
    	    
        # 最高販売価格
    end
end
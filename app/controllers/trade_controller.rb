class TradeController < ApplicationController
    # include Arbitrage
    def home
    end
    
    # 取引履歴を表示
    def tradeHistory
        offset = params[:offset].to_i
        @history = TradeInfo.offset(offset).order("created_at desc").limit(100).where(trade: true)
    end
    
    # 資産履歴を表示
    def assetHistory
        offset = params[:offset].to_i
        @history = Asset.offset(offset).order("created_at desc").limit(100).select("id, coincheck_jpy, coincheck_btc, zaif_jpy, zaif_btc, (coincheck_jpy + zaif_jpy) as total_jpy, (coincheck_btc + zaif_btc) as total_btc, created_at")
    end
    
    def graph
        
        offset = params[:offset].to_i
        # 資産推移をグラフで表示
        
        # 情報準備(直近１時間の情報を取得)
        # aHourAgo =  1.hour.ago.time.strftime("%Y-%m-%d %H:%M:%S")
        
        # assetHistory = Asset.where("created_at > " + "\"" + aHourAgo + "\"").group("strftime('%Y-%m-%d %H:%M:%S', created_at)").order("created_at desc").limit(100)
        
        # 直近100件の資産情報を取得
        assetHistory = Asset.order("created_at desc").offset(offset).limit(100)
        
        
        assetHistory = assetHistory.reverse
        
        # 各データ準備
        labelDatas = []
        dataDatas = []
        assetHistory.each do |asset|
            labelDatas.push(asset.created_at)
            dataDatas.push(asset.coincheck_jpy + asset.zaif_jpy)
        end
    
        
        # グラフの種類
        type = "line"
        # グラフデータ
        labels = labelDatas
        label = "資産推移"
        # 資産情報
        data = dataDatas
        # 背景色
        backgroundColor = [
            'rgba(255, 99, 132, 0.2)',
            'rgba(54, 162, 235, 0.2)',
            'rgba(255, 206, 86, 0.2)',
            'rgba(75, 192, 192, 0.2)',
            'rgba(153, 102, 255, 0.2)',
            'rgba(255, 159, 64, 0.2)'
        ]
        # 線の色
        borderColor = [
            'rgba(255,99,132,1)',
            'rgba(54, 162, 235, 1)',
            'rgba(255, 206, 86, 1)',
            'rgba(75, 192, 192, 1)',
            'rgba(153, 102, 255, 1)',
            'rgba(255, 159, 64, 1)'
        ]
        # 線の幅
        borderWidth = 1
        
        # グラフデータ作成
        @data = JSON.generate(
            type: type,
            data: {
                labels: labels,
                datasets: [{
                    label: label,
                    data: data,
                    backgroundColor: backgroundColor,
                    borderColor: borderColor,
                    borderWidth: borderWidth
                }]
            }
        )
    end
    
    def ajax
        # 価格情報をjsonで出力
        
        asset = Asset.last
        value = Value.last
        profit = Profit.last
        
        tradeInfo = TradeInfo.last
        
        # coincheck総資産
        coincheck_asset = asset.coincheck_jpy + (asset.coincheck_btc * value.coincheck_bid)
        # zaif総資産
        zaif_asset = asset.zaif_jpy + (asset.zaif_btc * value.zaif_bid)
        # 総資産
        total_asset = coincheck_asset + zaif_asset
        
        # 資産リセットからの総利益
        init_asset = Asset.reset_info
        
        @data = [
            "asset": asset,
            "value": value,
            "profit": profit,
            "coincheck_asset": coincheck_asset,
            "zaif_asset": zaif_asset,
            "total_asset": total_asset,
            "trade_info": tradeInfo,
            "init_asset": init_asset,
        ]
        render :json => @data.as_json
    end
end
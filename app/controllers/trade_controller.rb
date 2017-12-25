class TradeController < ApplicationController
    # include Arbitrage
    def home
    end
    
    def graph
        # 資産推移をグラフで表示
        
        # 情報準備(直近１時間の情報を取得)
        aHourAgo =  1.hour.ago.time.strftime("%Y-%m-%d %H:%M:%S")
        
        assetHistory = Asset.where("created_at > " + "\"" + aHourAgo + "\"").group("strftime('%Y-%m-%d %H:%M:%S', created_at)").order("created_at desc").limit(100)
        
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
        
        # coincheck総資産
        coincheck_asset = asset.coincheck_jpy + (asset.coincheck_btc * value.coincheck_bid)
        # zaif総資産
        zaif_asset = asset.zaif_jpy + (asset.zaif_btc * value.zaif_bid)
        # 総資産
        total_asset = coincheck_asset + zaif_asset
        
        @data = [
            "asset": asset,
            "value": value,
            "profit": profit,
            "coincheck_asset": coincheck_asset,
            "zaif_asset": zaif_asset,
            "total_asset": total_asset
        ]
        render :json => @data
    end
end
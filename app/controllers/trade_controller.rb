class TradeController < ApplicationController
    include Arbitrage
    def home
    end
    
    def graph
        # 資産推移をグラフで表示
        
        # 情報準備(直近１時間の情報を取得)
        aHourAgo =  10.hour.ago.time.strftime("%Y-%m-%d %H:%M:%S")
        
        assetHistory = Asset.where("created_at > " + "\"" + aHourAgo + "\"").group("strftime('%Y-%m-%d %H:%M', created_at)").order("created_at asc")
        
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
        
        # p = DataUpdate.new
        # profit = p.profit
        @data = [
            "asset": asset,
            "value": value,
            "profit": profit
        ]
        render :json => @data
    end
end
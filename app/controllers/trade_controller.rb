class TradeController < ApplicationController
    include Arbitrage
    def home
    end
    
    def graph
        # 資産推移をグラフで表示
        
        # グラフの種類
        type = "line"
        # グラフデータ
        labels = ["Red", "Blue", "Yellow", "Green", "Purple", "Orange"]
        label = "資産推移"
        # 資産情報
        data = [12, 19, 3, 5, 2, 3]
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
        
        p = DataUpdate.new
        profit = p.profit
        @data = [
            "asset": asset,
            "value": value,
            "profit": profit
        ]
        render :json => @data
    end
end
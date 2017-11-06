
=begin

    裁定取引に関わる処理全般を行う
    -- 価格取得 --
    -- 売買判断 --
        
=end
module Arbitrage
    extend ActiveSupport::Concern # インスタンスメソッドのみの利用時は記述の必要なし
    
    # 各種価格の取得
    class GetValue
        
        def self.coincheckBid
            
        end
        
        def self.coincheckAsk
        end
        
    end
    
end
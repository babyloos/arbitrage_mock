class ConfigController < ApplicationController
    
    # メニュー一覧
    def home
        @asset = Asset.new
    end
    
    # 資産リセット
    def reset
        # 資産情報をリセット
        Asset.reset_asset(post_params)
        redirect_to :controller => :trade, :action => :home
    end
    
    private
    
    def post_params
      # submitしたデータのうち、Model作成に必要なものを
      # permitの引数に指定する
      params.require(:asset).permit(
        :coincheck_jpy, :coincheck_btc, :zaif_jpy, :zaif_btc
      )
    end
end

class Asset < ActiveRecord::Base
    
    # 資産情報をリセット
    def self.reset_asset(asset)
        asset = Asset.new(asset)
        asset.save
    end
end

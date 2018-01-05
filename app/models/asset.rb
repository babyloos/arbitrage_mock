class Asset < ActiveRecord::Base
    
    # 資産情報をリセット
    def self.reset_asset(asset)
        asset = Asset.create(asset)
        # リセット情報を保存
        ResetLog.create({asset_id: asset.id})
    end
    
    # リセット時点の資産を取得
    def self.reset_info
        # 最新のリセット時点のAsset id
        reset_asset = ResetLog.select("asset_id").order("created_at desc").limit(1)
        Asset.where("id = " + reset_asset.last.asset_id.to_s).last
    end
    
end

namespace :update_value do
    
    desc "仮想通貨の価格情報を更新"
    
    task :update => :environment do
        include ArbitrageMock
        asset = Asset.last
        d = ArbitrageMock::ArbitrageMock.new(asset)
        d.debug
    end
end

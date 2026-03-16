# frozen_string_literal: true

# Monthly job to fully sync shops, machines, and details from DMMぱちタウン.
# Runs on the 1st of each month at 03:00 JST.
class MonthlyShopDetailsJob < ApplicationJob
  queue_as :default

  def perform
    $stdout.sync = true

    # 1. 店舗マスタ更新（全国）
    Rails.logger.info("[MonthlyShopDetails] Importing shops from DMMぱちタウン...")
    Rake::Task["ptown:import_shops"].invoke
    Rake::Task["ptown:import_shops"].reenable

    # 2. 機種マスタ更新（新台 + 詳細）
    Rails.logger.info("[MonthlyShopDetails] Importing machines and details...")
    Rake::Task["ptown:import_machines"].invoke
    Rake::Task["ptown:import_machines"].reenable
    Rake::Task["ptown:import_details"].invoke
    Rake::Task["ptown:import_details"].reenable

    # 3. 全店の設置機種同期
    Rails.logger.info("[MonthlyShopDetails] Syncing shop machines...")
    Rake::Task["ptown:sync_shop_machines"].invoke
    Rake::Task["ptown:sync_shop_machines"].reenable

    # 4. 孤立機種を非アクティブ化
    MachineModel.active
      .left_joins(:shop_machine_models)
      .where(shop_machine_models: { id: nil })
      .update_all(active: false)

    Rails.logger.info("[MonthlyShopDetails] Done")
  end
end

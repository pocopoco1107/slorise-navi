# frozen_string_literal: true

# Daily job to sync machine master and shop machines from DMMぱちタウン.
# Runs at 03:00 JST (~4-5 hours).
# Skipped on the 1st of each month when MonthlyShopDetailsJob runs instead.
class DailyMachineRefreshJob < ApplicationJob
  queue_as :default

  def perform
    return if Date.current.day == 1

    $stdout.sync = true

    # 1. 機種マスタ更新（新台取り込み）
    Rails.logger.info("[DailyMachineRefresh] Importing machines from DMMぱちタウン...")
    Rake::Task["ptown:import_machines"].invoke
    Rake::Task["ptown:import_machines"].reenable

    # 2. 全店の設置機種同期（台数 + 店舗詳細）
    Rails.logger.info("[DailyMachineRefresh] Syncing shop machines...")
    Rake::Task["ptown:sync_shop_machines"].invoke
    Rake::Task["ptown:sync_shop_machines"].reenable

    # 3. 孤立機種を非アクティブ化
    MachineModel.active
      .left_joins(:shop_machine_models)
      .where(shop_machine_models: { id: nil })
      .update_all(active: false)

    Rails.logger.info("[DailyMachineRefresh] Done")
  end
end

# frozen_string_literal: true

# Daily job to sync all shops from P-WORLD in a single pass.
# 1 HTTP request per shop → machines + unit counts updated together.
# Runs at 03:00 JST (~4 hours). Skipped on the 1st of each month
# when MonthlyShopDetailsJob runs instead.
class DailyMachineRefreshJob < ApplicationJob
  queue_as :default

  def perform
    return if Date.current.day == 1

    $stdout.sync = true
    total = Shop.where.not(pworld_url: [nil, ""]).count
    synced = 0

    Shop.where.not(pworld_url: [nil, ""]).includes(:prefecture).find_each.with_index do |shop, index|
      begin
        PworldScraper.sync_shop_from_pworld(shop, cleanup_stale: true, update_details: false)
        synced += 1
      rescue => e
        Rails.logger.warn("[DailyMachineRefresh] #{shop.name}: #{e.message}")
      end
      sleep(PworldScraper::REQUEST_INTERVAL)
      puts "#{index + 1}/#{total} ..." if (index + 1) % 500 == 0
    end

    # Deactivate orphan machines
    MachineModel.active
      .left_joins(:shop_machine_models)
      .where(shop_machine_models: { id: nil })
      .update_all(active: false)

    Rails.logger.info("[DailyMachineRefresh] Done: #{synced}/#{total} shops synced")
  end
end

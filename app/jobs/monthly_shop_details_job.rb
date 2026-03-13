# frozen_string_literal: true

# Monthly job to fully sync all shops from P-WORLD (1st of each month).
# 1 HTTP request per shop → machines + unit counts + shop details.
class MonthlyShopDetailsJob < ApplicationJob
  queue_as :default

  def perform
    $stdout.sync = true
    total = Shop.where.not(pworld_url: [nil, ""]).count
    synced = 0

    Shop.where.not(pworld_url: [nil, ""]).includes(:prefecture).find_each.with_index do |shop, index|
      begin
        result = PworldScraper.sync_shop_from_pworld(shop, cleanup_stale: true, update_details: true)
        synced += 1 if result
      rescue => e
        Rails.logger.warn("[MonthlyShopDetails] #{shop.name}: #{e.message}")
      end
      sleep(PworldScraper::REQUEST_INTERVAL)
      puts "#{index + 1}/#{total} ..." if (index + 1) % 500 == 0
    end

    # Deactivate orphan machines
    MachineModel.active
      .left_joins(:shop_machine_models)
      .where(shop_machine_models: { id: nil })
      .update_all(active: false)

    Rails.logger.info("[MonthlyShopDetails] Done: #{synced}/#{total} shops synced")
  end
end

class RefreshPlayRecordSummaryJob < ApplicationJob
  queue_as :default

  def perform(play_record_id)
    record = PlayRecord.find_by(id: play_record_id)
    return unless record

    month_key = record.played_on.strftime("%Y-%m")

    if record.machine_model_id
      PlayRecordSummary.refresh_for_machine_model!(record.machine_model_id, period_key: month_key)
      PlayRecordSummary.refresh_for_machine_model!(record.machine_model_id, period_key: nil)
    end

    PlayRecordSummary.refresh_for_shop!(record.shop_id, period_key: month_key)
    PlayRecordSummary.refresh_for_shop!(record.shop_id, period_key: nil)

    prefecture_id = record.shop&.prefecture_id
    if prefecture_id
      PlayRecordSummary.refresh_for_prefecture!(prefecture_id, period_key: month_key)
      PlayRecordSummary.refresh_for_prefecture!(prefecture_id, period_key: nil)
    end
  end
end

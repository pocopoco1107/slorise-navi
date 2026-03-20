class ExchangeRateSummary < ApplicationRecord
  belongs_to :shop

  enum :denomination, { twenty_yen: 0, five_yen: 1 }

  validates :shop_id, uniqueness: { scope: :denomination }

  def self.refresh_for(shop_id, denomination)
    lock_key = [ "exchange_rate", shop_id, denomination ].join("-").hash.abs % (2**31)

    transaction do
      connection.exec_query("SELECT pg_advisory_xact_lock($1)", "advisory_lock", [ lock_key ])

      reports = ExchangeRateReport.where(shop_id: shop_id, denomination: denomination).pluck(:rate_key)
      summary = find_or_initialize_by(shop_id: shop_id, denomination: denomination)

      distribution = reports.tally
      summary.rate_distribution = distribution
      summary.total_reports = reports.size
      summary.consensus_rate = determine_consensus(distribution, reports.size)

      summary.save!
      summary
    end
  end

  def consensus_label
    return nil if consensus_rate.blank?
    self.class.rate_label(consensus_rate, denomination)
  end

  def self.rate_label(rate_key, denomination)
    return "等価" if rate_key == "touka"
    denomination.to_s == "twenty_yen" ? "#{rate_key}円/枚" : "#{rate_key}枚交換"
  end

  def confidence_level
    case total_reports
    when 0      then :none
    when 1..2   then :low
    when 3..9   then :medium
    else             :high
    end
  end

  private

  def self.determine_consensus(distribution, total)
    return nil if total < 2

    distribution.each do |key, count|
      return key if count.to_f / total > 0.5
    end

    nil
  end
end

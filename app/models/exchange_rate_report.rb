class ExchangeRateReport < ApplicationRecord
  enum :denomination, { twenty_yen: 0, five_yen: 1 }

  belongs_to :shop

  validates :voter_token, presence: true, uniqueness: { scope: [ :shop_id, :denomination ] }
  validates :rate_key, presence: true
  validate :rate_key_format
  validates :denomination, presence: true

  after_save :update_summary
  after_destroy :update_summary

  def rate_label
    ExchangeRateSummary.rate_label(rate_key, denomination)
  end

  private

  def rate_key_format
    return if rate_key == "touka"
    return if denomination.blank?

    unless rate_key.match?(/\A\d+(\.\d{1,2})?\z/)
      errors.add(:rate_key, "は「等価」または数値で入力してください")
      return
    end

    val = rate_key.to_f
    if twenty_yen?
      unless val.between?(1.0, 20.0)
        errors.add(:rate_key, "は1.0〜20.0円/枚の範囲で入力してください")
      end
    else
      unless val.between?(1.0, 50.0)
        errors.add(:rate_key, "は1.0〜50.0枚の範囲で入力してください")
      end
    end
  end

  def update_summary
    ExchangeRateSummary.refresh_for(shop_id, denomination_before_type_cast)
  end
end

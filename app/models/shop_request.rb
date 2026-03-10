class ShopRequest < ApplicationRecord
  belongs_to :prefecture

  enum :status, { pending: 0, approved: 1, rejected: 2 }

  validates :name, presence: true, length: { maximum: 100 }
  validates :address, length: { maximum: 200 }, allow_blank: true
  validates :url, length: { maximum: 500 }, allow_blank: true
  validates :note, length: { maximum: 500 }, allow_blank: true
  validates :voter_token, presence: true

  validate :no_duplicate_pending_request
  validate :daily_limit_not_exceeded, on: :create

  DAILY_LIMIT = 3

  scope :pending, -> { where(status: :pending) }
  scope :approved, -> { where(status: :approved) }
  scope :rejected, -> { where(status: :rejected) }

  private

  def no_duplicate_pending_request
    return if prefecture_id.blank? || name.blank?

    existing = ShopRequest.pending.where(prefecture_id: prefecture_id, name: name)
    existing = existing.where.not(id: id) if persisted?

    if existing.exists?
      errors.add(:base, "同じ都道府県・店舗名の申請がすでに審査待ちです")
    end
  end

  def daily_limit_not_exceeded
    return if voter_token.blank?

    today_count = ShopRequest.where(voter_token: voter_token)
                             .where("created_at >= ?", Time.current.beginning_of_day)
                             .count

    if today_count >= DAILY_LIMIT
      errors.add(:base, "1日の申請上限（#{DAILY_LIMIT}件）に達しています。明日またお試しください")
    end
  end
end

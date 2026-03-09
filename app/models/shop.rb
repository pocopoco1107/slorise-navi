class Shop < ApplicationRecord
  belongs_to :prefecture
  has_many :votes, dependent: :destroy
  has_many :vote_summaries, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  # Exchange rate enum
  attribute :exchange_rate, :integer, default: 0
  enum :exchange_rate, {
    unknown_rate: 0,
    equal_rate: 1,     # 等価
    rate_56: 2,        # 5.6枚交換
    rate_50: 3,        # 5.0枚交換
    non_equal: 4       # 非等価(その他)
  }

  # Available slot rates
  SLOT_RATES = %w[20スロ 10スロ 5スロ 2スロ 1スロ].freeze

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
  validate :valid_slot_rates

  include PgSearch::Model
  pg_search_scope :search_by_name, against: :name, using: { tsearch: { prefix: true } }

  def to_param
    slug
  end

  def slot_rates_display
    slot_rates.presence&.join(" / ") || "未設定"
  end

  def exchange_rate_display
    case exchange_rate
    when "equal_rate" then "等価"
    when "rate_56" then "5.6枚交換"
    when "rate_50" then "5.0枚交換"
    when "non_equal" then "非等価"
    else "未設定"
    end
  end

  private

  def valid_slot_rates
    return if slot_rates.blank?

    invalid = slot_rates - SLOT_RATES
    errors.add(:slot_rates, "に無効なレート(#{invalid.join(', ')})が含まれています") if invalid.any?
  end
end

class ShopEvent < ApplicationRecord
  belongs_to :shop

  enum :event_type, {
    filming: 0,       # 取材
    special_day: 1,   # 特定日
    new_machine: 2,   # 新台入替
    remodel: 3,       # リニューアル
    other: 4          # その他
  }

  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2
  }

  SOURCES = %w[user ptown].freeze

  validates :event_date, presence: true
  validates :event_type, presence: true
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  validates :source_url, length: { maximum: 500 }, allow_blank: true
  validates :voter_token, presence: true, unless: :auto_collected?
  validates :source, inclusion: { in: SOURCES }
  validate :event_date_within_range, if: -> { event_date.present? && source == "user" }

  scope :upcoming, -> { where("event_date >= ?", Date.current).order(event_date: :asc) }
  scope :past, -> { where("event_date < ?", Date.current).order(event_date: :desc) }
  scope :visible, -> { approved }
  scope :recent, -> { order(created_at: :desc) }

  EVENT_TYPE_LABELS = {
    "filming" => "取材",
    "special_day" => "特定日",
    "new_machine" => "新台入替",
    "remodel" => "リニューアル",
    "other" => "その他"
  }.freeze

  EVENT_TYPE_COLORS = {
    "filming" => "text-chart-1 bg-chart-1/10",
    "special_day" => "text-chart-5 bg-chart-5/10",
    "new_machine" => "text-chart-3 bg-chart-3/10",
    "remodel" => "text-chart-4 bg-chart-4/10",
    "other" => "text-muted-foreground bg-muted"
  }.freeze

  def event_type_label
    EVENT_TYPE_LABELS[event_type] || event_type
  end

  def event_type_color
    EVENT_TYPE_COLORS[event_type] || "text-muted-foreground bg-muted"
  end

  def upcoming?
    event_date >= Date.current
  end

  def auto_collected?
    source == "ptown"
  end

  private

  def event_date_within_range
    min_date = Date.current - 30.days
    max_date = Date.current + 60.days
    unless event_date.between?(min_date, max_date)
      errors.add(:event_date, "は過去30日〜未来60日の範囲で指定してください")
    end
  end
end

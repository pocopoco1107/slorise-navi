module TrendData
  extend ActiveSupport::Concern

  private

  # Build 7-day trend data for a given VoteSummary scope.
  # Returns an array of hashes: [{ date:, votes:, reset_rate:, setting_avg: }, ...]
  # Days with no data are filled with zeros/nils.
  def build_trend_data(scope, days: 7)
    end_date = Date.current
    start_date = end_date - (days - 1)
    date_range = (start_date..end_date).to_a

    # Single aggregate query grouped by date
    rows = scope
      .where(target_date: start_date..end_date)
      .group(:target_date)
      .pluck(
        Arel.sql("target_date"),
        Arel.sql("COALESCE(SUM(total_votes), 0)"),
        Arel.sql("COALESCE(SUM(reset_yes_count), 0)"),
        Arel.sql("COALESCE(SUM(reset_no_count), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN setting_avg * total_votes ELSE 0 END), 0)"),
        Arel.sql("COALESCE(SUM(CASE WHEN total_votes > 0 AND setting_avg IS NOT NULL THEN total_votes ELSE 0 END), 0)")
      )

    by_date = rows.each_with_object({}) do |row, h|
      date = row[0]
      total_votes = row[1].to_i
      reset_yes = row[2].to_i
      reset_no = row[3].to_i
      total_reset = reset_yes + reset_no
      weighted_sum = row[4].to_f
      weighted_count = row[5].to_i

      h[date] = {
        votes: total_votes,
        reset_rate: total_reset >= 3 ? (reset_yes.to_f / total_reset * 100).round(1) : nil,
        setting_avg: weighted_count > 0 ? (weighted_sum / weighted_count).round(1) : nil
      }
    end

    date_range.map do |date|
      data = by_date[date] || { votes: 0, reset_rate: nil, setting_avg: nil }
      { date: date }.merge(data)
    end
  end
end

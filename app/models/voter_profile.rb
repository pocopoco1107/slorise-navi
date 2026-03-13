class VoterProfile < ApplicationRecord
  RANK_TITLES = [
    { title: "伝説の記録者", min_votes: 1000, min_accuracy: 70.0 },
    { title: "設定看破マスター", min_votes: 300, min_accuracy: 60.0 },
    { title: "目利き師", min_votes: 100, min_accuracy: 40.0 },
    { title: "常連", min_votes: 50 },
    { title: "記録者", min_votes: 10 },
    { title: "見習い", min_votes: 0 }
  ].freeze

  validates :voter_token, presence: true, uniqueness: true

  # --- Class methods ---

  def self.refresh_for(voter_token)
    votes = Vote.where(voter_token: voter_token)
    return nil if votes.none?

    profile = find_or_initialize_by(voter_token: voter_token)

    # Basic counts
    profile.total_votes = votes.count
    profile.weekly_votes = votes.where(voted_on: Date.current.beginning_of_week..Date.current.end_of_week).count
    profile.monthly_votes = votes.where(voted_on: Date.current.beginning_of_month..Date.current.end_of_month).count

    # Streak calculation
    dates = votes.distinct.pluck(:voted_on).sort.reverse
    profile.last_voted_on = dates.first

    streak = calculate_streak(dates)
    profile.current_streak = streak
    profile.max_streak = [streak, profile.max_streak || 0].max

    # Accuracy rates
    profile.accuracy_confirmed = nil # Will implement in batch later
    profile.accuracy_majority = calculate_accuracy_majority(voter_token, votes)
    profile.high_setting_rate = calculate_high_setting_rate(votes)

    # Rank title
    profile.rank_title = determine_rank(profile.total_votes, profile.accuracy_majority)

    profile.save!
    profile
  end

  def self.next_rank_for(profile)
    current_found = false
    RANK_TITLES.reverse_each do |rank|
      if current_found
        votes_needed = [rank[:min_votes] - profile.total_votes, 0].max
        accuracy_needed = rank[:min_accuracy] && (profile.accuracy_majority.nil? || profile.accuracy_majority < rank[:min_accuracy]) ? rank[:min_accuracy] : nil
        return {
          title: rank[:title],
          votes_needed: votes_needed,
          accuracy_needed: accuracy_needed
        } if votes_needed > 0 || accuracy_needed
      end
      current_found = true if rank[:title] == profile.rank_title
    end
    nil
  end

  private

  def self.calculate_streak(dates)
    return 0 if dates.empty?

    streak = 0
    expected = Date.current

    # Allow starting from yesterday if no vote today
    if dates.first == expected
      streak = 1
      expected = expected - 1.day
      dates = dates.drop(1)
    elsif dates.first == expected - 1.day
      expected = expected - 1.day
    else
      return 0
    end

    dates.each do |d|
      if d == expected
        streak += 1
        expected = d - 1.day
      else
        break
      end
    end

    streak
  end

  def self.calculate_accuracy_majority(voter_token, votes)
    setting_votes = votes.where.not(setting_vote: nil)
    return nil if setting_votes.count < 5

    # Preload only the exact VoteSummaries needed (avoids Cartesian product)
    vote_keys = setting_votes.pluck(:shop_id, :machine_model_id, :voted_on)
    return nil if vote_keys.empty?

    conditions = vote_keys.map { "(?, ?, ?)" }.join(", ")
    flat_values = vote_keys.flatten
    summaries = VoteSummary.where(
      "(shop_id, machine_model_id, target_date) IN (#{conditions})", *flat_values
    ).index_by { |s| [s.shop_id, s.machine_model_id, s.target_date] }

    matches = 0
    total = 0

    setting_votes.find_each do |vote|
      summary = summaries[[vote.shop_id, vote.machine_model_id, vote.voted_on]]
      next unless summary&.setting_distribution.present?

      distribution = summary.setting_distribution
      next if distribution.values.sum < 3 # Need enough votes for meaningful majority

      mode_setting = distribution.max_by { |_k, v| v }&.first&.to_i
      next unless mode_setting

      total += 1
      matches += 1 if vote.setting_vote == mode_setting
    end

    return nil if total.zero?
    (matches.to_f / total * 100).round(1)
  end

  def self.calculate_high_setting_rate(votes)
    setting_votes = votes.where.not(setting_vote: nil)
    total = setting_votes.count
    return nil if total < 5

    high_count = setting_votes.where(setting_vote: [4, 5, 6]).count
    (high_count.to_f / total * 100).round(1)
  end

  def self.determine_rank(total_votes, accuracy)
    RANK_TITLES.each do |rank|
      next if total_votes < rank[:min_votes]
      if rank[:min_accuracy]
        next if accuracy.nil? || accuracy < rank[:min_accuracy]
      end
      return rank[:title]
    end
    "見習い"
  end
end

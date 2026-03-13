class VoterController < ApplicationController
  def status
    set_meta_tags title: "マイステータス", noindex: true

    token = cookies[:voter_token]

    if token.blank?
      @has_votes = false
      return
    end

    @profile = VoterProfile.find_by(voter_token: token)
    @has_votes = @profile.present? && @profile.total_votes > 0

    return unless @has_votes

    votes = Vote.where(voter_token: token)
    @total_votes_count = @profile.total_votes
    @shops_count = votes.distinct.count(:shop_id)
    @machines_count = votes.distinct.count(:machine_model_id)
    @prefectures_count = votes.joins(:shop).distinct.count("shops.prefecture_id")

    @recent_votes = votes.includes(:shop, :machine_model)
                         .order(voted_on: :desc, updated_at: :desc)
                         .limit(10)

    @badges = compute_badges(
      total_votes: @total_votes_count,
      prefectures_count: @prefectures_count,
      machines_count: @machines_count
    )

    # Streak data for view (last 7 days)
    @streak_days = build_streak_calendar(token)

    @voter_label = "ユーザー##{token.last(4)}"
  end

  def restore
    token = params[:token]&.strip
    if token.present? && Vote.exists?(voter_token: token)
      cookies.permanent[:voter_token] = token
      redirect_to voter_status_path, notice: "トークンを復元しました"
    else
      redirect_to voter_status_path, alert: "該当するトークンが見つかりませんでした"
    end
  end

  private

  BADGE_DEFINITIONS = [
    { key: :first_vote,    icon: "\u{1F3B0}", name: "初記録",       description: "1件以上記録",         check: ->(s) { s[:total_votes] >= 1 } },
    { key: :contributor,   icon: "\u{1F4CA}", name: "データ提供者",  description: "10件以上記録",        check: ->(s) { s[:total_votes] >= 10 } },
    { key: :regular,       icon: "\u{1F3C6}", name: "常連記録者",    description: "50件以上記録",        check: ->(s) { s[:total_votes] >= 50 } },
    { key: :expert,        icon: "\u2B50",    name: "エキスパート",  description: "100件以上記録",       check: ->(s) { s[:total_votes] >= 100 } },
    { key: :master,        icon: "\u{1F451}", name: "マスター",      description: "500件以上記録",       check: ->(s) { s[:total_votes] >= 500 } },
    { key: :traveler,      icon: "\u{1F5FA}", name: "旅打ち",       description: "3県以上で記録",       check: ->(s) { s[:prefectures_count] >= 3 } },
    { key: :machine_mania, icon: "\u{1F3AF}", name: "機種マニア",    description: "10機種以上で記録",    check: ->(s) { s[:machines_count] >= 10 } }
  ].freeze

  def compute_badges(stats)
    BADGE_DEFINITIONS.map do |badge|
      badge.merge(earned: badge[:check].call(stats))
    end
  end

  def build_streak_calendar(token)
    today = Date.current
    dates_range = (today - 6.days)..today
    voted_dates = Vote.where(voter_token: token, voted_on: dates_range)
                      .distinct.pluck(:voted_on).to_set

    (0..6).map do |i|
      day = today - (6 - i).days
      {
        label: ApplicationHelper::DAY_LABELS[day.wday],
        date: day,
        voted: voted_dates.include?(day)
      }
    end
  end
end

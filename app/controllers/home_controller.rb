class HomeController < ApplicationController
  include TrendData

  def index
    desc = "全国5,700店舗のパチスロ設定・リセット傾向を匿名で記録・可視化。収支カレンダーで自分のデータも管理できる無料サイト。"
    set_meta_tags title: "パチスロ設定・リセット記録",
                  description: desc,
                  keywords: "パチスロ, 設定, リセット, 記録, 設定判別, スロット",
                  og: { title: "ヨミスロ - パチスロ設定・リセット記録",
                        description: desc,
                        type: "website",
                        url: root_url },
                  twitter: { card: "summary" }

    @prefectures = Prefecture.left_joins(:shops).group(:id).select("prefectures.*, COUNT(shops.id) as shops_count").order(:id)

    # Stats for hero (cached to avoid full table scans on every request)
    @today_votes_count = Rails.cache.fetch("home/today_votes", expires_in: 5.minutes) { Vote.where(voted_on: Date.current).count }
    @total_votes_count = Rails.cache.fetch("home/total_votes", expires_in: 10.minutes) { Vote.count }
    @shops_count = Rails.cache.fetch("home/shops_count", expires_in: 1.hour) { Shop.count }
    @machines_count = Rails.cache.fetch("home/machines_count", expires_in: 1.hour) {
      MachineModel.active
        .joins(:shop_machine_models)
        .group("machine_models.id")
        .having("COUNT(shop_machine_models.id) >= 50")
        .count.size
    }

    # Today's hot shops — single query with JOIN to avoid N+1
    hot_shop_rows = VoteSummary.where(target_date: Date.current)
                               .group(:shop_id)
                               .select("shop_id, SUM(total_votes) as vote_total")
                               .order("vote_total DESC")
                               .limit(5)
    hot_shop_ids = hot_shop_rows.map(&:shop_id)
    hot_shops_by_id = Shop.where(id: hot_shop_ids).index_by(&:id)
    @hot_shops = hot_shop_rows.filter_map { |vs|
      shop = hot_shops_by_id[vs.shop_id]
      next unless shop
      { shop: shop, votes: vs.vote_total }
    }

    # High reset rate machines — limit candidate rows in SQL, then pick top 5
    reset_rows = VoteSummary.where(target_date: Date.current)
                            .where("reset_yes_count + reset_no_count >= 3")
                            .select("id, machine_model_id, shop_id, reset_yes_count, reset_no_count")
                            .order(Arel.sql("reset_yes_count::float / NULLIF(reset_yes_count + reset_no_count, 0) DESC"))
                            .limit(20)
                            .to_a
    if reset_rows.any?
      machine_ids = reset_rows.map(&:machine_model_id).uniq
      shop_ids = reset_rows.map(&:shop_id).uniq
      machines_by_id = MachineModel.where(id: machine_ids).select(:id, :name, :slug).index_by(&:id)
      shops_by_id = Shop.where(id: shop_ids).select(:id, :name, :slug, :prefecture_id).index_by(&:id)

      @high_reset_machines = reset_rows
        .first(5)
        .filter_map { |vs|
          machine = machines_by_id[vs.machine_model_id]
          shop = shops_by_id[vs.shop_id]
          next unless machine && shop
          { machine: machine, shop: shop, rate: vs.reset_rate }
        }
    else
      @high_reset_machines = []
    end

    # Weekly voter ranking — top 10 by vote count this week
    week_start = Date.current.beginning_of_week
    @weekly_ranking = Vote.where(voted_on: week_start..Date.current)
                          .group(:voter_token)
                          .order(Arel.sql("COUNT(*) DESC"))
                          .limit(10)
                          .pluck(Arel.sql("voter_token, COUNT(*) as vote_count"))
                          .map.with_index(1) { |(token, count), rank|
                            { rank: rank, label: "ユーザー##{token.last(4)}", count: count }
                          }

    # 7-day nationwide trend (scoped to last 7 days to avoid full table scan)
    @trend_data = build_trend_data(VoteSummary.where(target_date: 6.days.ago.to_date..Date.current))

    # AI おすすめ店舗 (全国TOP5)
    @recommendations = RecommendationService.top_nationwide(limit: 5)

    @recent_shops = Shop.includes(:prefecture).order(updated_at: :desc).limit(10)

    # Play records count for pillar card
    @play_records_count = Rails.cache.fetch("home/play_records_count", expires_in: 10.minutes) { PlayRecord.count }

    # Personal play summary for mini card
    token = cookies[:voter_token]
    if token.present?
      agg = PlayRecord.where(voter_token: token, played_on: Date.current.beginning_of_month..Date.current)
                      .pick(
                        Arel.sql("SUM(result_amount)"),
                        Arel.sql("COUNT(DISTINCT played_on)"),
                        Arel.sql("COUNT(*) FILTER (WHERE result_amount > 0)"),
                        Arel.sql("COUNT(*) FILTER (WHERE result_amount < 0)")
                      )
      if agg&.first
        total, days, wins, losses = agg
        win_rate = (wins + losses) > 0 ? (wins.to_f / (wins + losses) * 100).round(0) : 0
        @my_play_summary = { total: total.to_i, days: days.to_i, win_rate: win_rate }
      end
    end

    if params[:q].present?
      @search_results = Shop.search_by_name(params[:q]).includes(:prefecture).limit(20)
    end

    if params[:mq].present?
      @machine_results = MachineModel.active.where("name ILIKE ?", "%#{MachineModel.sanitize_sql_like(params[:mq])}%").order(:name).limit(20)
    end
  end
end

class HomeController < ApplicationController
  def index
    set_meta_tags title: "パチスロ設定・リセット投票",
                  description: "パチスロの設定・リセット情報をみんなの投票で集める。店舗×機種×日付で設定予想を共有するサイト。",
                  keywords: "パチスロ, 設定, リセット, 投票, 設定判別, スロット"

    @prefectures = Prefecture.all.order(:id)

    # Stats for hero
    @today_votes_count = Vote.where(voted_on: Date.current).count
    @total_votes_count = Vote.count
    @shops_count = Shop.count
    @machines_count = MachineModel.count

    # Today's hot data
    @hot_shops = VoteSummary.where(target_date: Date.current)
                            .group(:shop_id)
                            .select("shop_id, SUM(total_votes) as vote_total")
                            .order("vote_total DESC")
                            .limit(5)
                            .map { |vs| { shop: Shop.find(vs.shop_id), votes: vs.vote_total } }

    @high_reset_machines = VoteSummary.where(target_date: Date.current)
                                       .where("reset_yes_count + reset_no_count >= 3")
                                       .select("machine_model_id, shop_id, reset_yes_count, reset_no_count")
                                       .sort_by { |vs| -vs.reset_rate.to_i }
                                       .first(5)
                                       .map { |vs| { machine: MachineModel.find(vs.machine_model_id), shop: Shop.find(vs.shop_id), rate: vs.reset_rate } }

    @recent_shops = Shop.includes(:prefecture).order(updated_at: :desc).limit(10)

    if params[:q].present?
      @search_results = Shop.search_by_name(params[:q]).includes(:prefecture).limit(20)
    end
  end
end

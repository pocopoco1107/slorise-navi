class SearchController < ApplicationController
  def index
    @prefectures = Prefecture.order(:id)
    @shops = search_shops

    set_meta_tags title: "全国店舗検索",
                  description: "全国のパチスロ店舗を条件で横断検索。",
                  keywords: "パチスロ, 店舗検索, 店舗"
  end

  private

  def search_shops
    scope = Shop.includes(:prefecture)

    # 都道府県（複数選択 OR）
    if params[:prefectures].present?
      pref_ids = Prefecture.where(slug: Array(params[:prefectures])).pluck(:id)
      scope = scope.where(prefecture_id: pref_ids) if pref_ids.any?
    end

    # 駐車場フィルタ
    if params[:facilities].present? && Array(params[:facilities]).include?("parking")
      scope = scope.where("parking_spaces IS NOT NULL AND parking_spaces > 0")
    end

    # 開店時間（OR） — sanitized via to_i
    if params[:opening_hours].present?
      hours = Array(params[:opening_hours]).map(&:to_i).uniq
      conditions = hours.map { |h| "business_hours LIKE ?" }
      binds = hours.map { |h| "#{h}:%" }
      scope = scope.where(conditions.join(" OR "), *binds)
    end

    # 朝入場ルール
    if params[:morning_entry] == "yes"
      scope = scope.where.not(morning_entry: [ nil, "" ])
    end

    # フリーワード（店舗名部分一致）
    if params[:q].present?
      scope = scope.where("shops.name LIKE ?", "%#{Shop.sanitize_sql_like(params[:q])}%")
    end

    scope.order(:prefecture_id, :name).page(params[:page]).per(30)
  end
end

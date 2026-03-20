require "rails_helper"

RSpec.describe "Prefectures", type: :request do
  let!(:prefecture) { create(:prefecture, name: "東京都", slug: "tokyo") }

  describe "GET /prefectures/:slug" do
    it "renders the prefecture page" do
      get prefecture_path("tokyo")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京都")
      expect(response.body).to include("店舗")
    end

    it "shows filter panel toggle button" do
      get prefecture_path("tokyo")
      expect(response.body).to include("絞り込み")
      expect(response.body).to include('data-controller="shop-filter machine-filter"')
    end

    it "renders filter checkboxes for opening hours" do
      get prefecture_path("tokyo")
      expect(response.body).to include("開店時間")
      expect(response.body).to include('value="9"')
      expect(response.body).to include('value="10"')
    end

    it "renders filter checkbox for morning entry" do
      get prefecture_path("tokyo")
      expect(response.body).to include("朝入場ルール")
    end

    it "renders shop cards with filter data attributes" do
      shop = create(:shop,
        prefecture: prefecture,
        name: "テスト等価店",
        business_hours: "9:00〜23:00",
        parking_spaces: 100,
        morning_entry: "整理券配布8:30")

      get prefecture_path("tokyo")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("テスト等価店")
      expect(response.body).to include('data-filter-morning="yes"')
      expect(response.body).to include('data-shop-card')
    end

    it "renders shop without optional fields" do
      create(:shop, prefecture: prefecture, name: "最低限店舗")

      get prefecture_path("tokyo")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("最低限店舗")
      expect(response.body).to include('data-filter-morning="no"')
    end

    it "shows result count display" do
      create(:shop, prefecture: prefecture)
      get prefecture_path("tokyo")
      expect(response.body).to include('data-shop-filter-target="count"')
      expect(response.body).to include('data-shop-filter-target="total"')
    end

    it "shows clear filter button" do
      get prefecture_path("tokyo")
      expect(response.body).to include("フィルタをクリア")
    end

    context "statistics reverse lookup" do
      before do
        create(:shop, prefecture: prefecture, name: "店舗A",
               business_hours: "9:00〜23:00",
               parking_spaces: 50, morning_entry: "整理券配布8:30")
        create(:shop, prefecture: prefecture, name: "店舗B",
               business_hours: "10:00〜22:45")
      end

      it "renders clickable opening hours stats with preset data" do
        get prefecture_path("tokyo")
        expect(response.body).to include('data-preset-category="hours"')
        expect(response.body).to include('data-preset-value="9"')
      end

      it "renders clickable parking stat with preset data" do
        get prefecture_path("tokyo")
        expect(response.body).to include('data-preset-value="parking"')
      end

      it "renders clickable morning entry stat with preset data" do
        get prefecture_path("tokyo")
        expect(response.body).to include('data-preset-category="morning"')
        expect(response.body).to include('data-preset-value="yes"')
      end

      it "shows hint text about clicking stats to filter" do
        get prefecture_path("tokyo")
        expect(response.body).to include("各項目をクリックすると店舗を絞り込めます")
      end
    end

    it "returns 404 for invalid slug" do
      get prefecture_path("nonexistent-pref")
      expect(response).to have_http_status(:not_found)
    end
  end
end

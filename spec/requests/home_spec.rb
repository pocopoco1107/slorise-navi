require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the home page" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("スロリセnavi")
    end

    it "displays search results" do
      shop = create(:shop)
      get root_path, params: { q: shop.name }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop.name)
    end

    it "displays prefectures" do
      pref = create(:prefecture, name: "東京都")
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("東京都")
    end

    it "displays stats counters" do
      get root_path
      expect(response).to have_http_status(:ok)
      # Stats section should be rendered
      expect(response.body).to include("店舗")
    end

    it "displays hot shops when votes exist today" do
      shop = create(:shop)
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      3.times { create(:vote, shop: shop, machine_model: machine, voted_on: Date.current, reset_vote: 1) }

      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "handles empty search query gracefully" do
      get root_path, params: { q: "" }
      expect(response).to have_http_status(:ok)
    end

    it "shows trend chart when past vote data exists" do
      shop = create(:shop)
      machine = create(:machine_model)
      ShopMachineModel.create!(shop: shop, machine_model: machine)
      # Create VoteSummary records directly (Vote model only allows today/yesterday)
      [Date.current, Date.current - 1, Date.current - 2].each do |date|
        VoteSummary.create!(shop: shop, machine_model: machine,
                            target_date: date, total_votes: 5,
                            reset_yes_count: 3, reset_no_count: 2,
                            setting_avg: 3.5)
      end

      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("過去7日間の全国投票推移")
    end

    it "does not show trend chart when no votes exist" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("過去7日間の全国投票推移")
    end

    it "returns no search results for nonexistent shop" do
      get root_path, params: { q: "存在しない店舗XXXX" }
      expect(response).to have_http_status(:ok)
    end
  end
end

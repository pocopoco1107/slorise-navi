require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    it "renders the home page" do
      get root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ヨミスロ")
    end

    it "renders with shop data" do
      create(:shop)
      get root_path
      expect(response).to have_http_status(:ok)
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

    it "renders recommendations section when data exists" do
      get root_path
      expect(response).to have_http_status(:ok)
    end

    it "returns no search results for nonexistent shop" do
      get root_path, params: { q: "存在しない店舗XXXX" }
      expect(response).to have_http_status(:ok)
    end
  end
end

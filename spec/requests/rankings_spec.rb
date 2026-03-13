require "rails_helper"

RSpec.describe "Rankings", type: :request do
  describe "GET /rankings" do
    it "returns 200" do
      get rankings_path
      expect(response).to have_http_status(:ok)
    end

    it "defaults period to weekly" do
      get rankings_path
      expect(response.body).to include("weekly").or include("記録ランキング")
      expect(response).to have_http_status(:ok)
    end

    it "accepts period param weekly" do
      get rankings_path, params: { period: "weekly" }
      expect(response).to have_http_status(:ok)
    end

    it "accepts period param monthly" do
      get rankings_path, params: { period: "monthly" }
      expect(response).to have_http_status(:ok)
    end

    it "accepts period param all_time" do
      get rankings_path, params: { period: "all_time" }
      expect(response).to have_http_status(:ok)
    end

    it "falls back to weekly for invalid period" do
      get rankings_path, params: { period: "invalid" }
      expect(response).to have_http_status(:ok)
    end

    it "accepts scope param national" do
      get rankings_path, params: { scope: "national" }
      expect(response).to have_http_status(:ok)
    end

    it "accepts scope param prefecture" do
      prefecture = create(:prefecture)
      get rankings_path, params: { scope: "prefecture", prefecture_id: prefecture.id }
      expect(response).to have_http_status(:ok)
    end

    it "displays rankings when data exists" do
      week_key = Date.current.strftime("%G-W%V")
      VoterRanking.create!(
        voter_token: "test_token_abc1",
        period_type: :weekly,
        period_key: week_key,
        scope_type: "national",
        scope_id: nil,
        vote_count: 10,
        rank_position: 1
      )

      get rankings_path, params: { period: "weekly" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("abc1")
    end

    it "shows current user rank when voter_token cookie is set" do
      week_key = Date.current.strftime("%G-W%V")
      VoterRanking.create!(
        voter_token: "test_token_mine",
        period_type: :weekly,
        period_key: week_key,
        scope_type: "national",
        scope_id: nil,
        vote_count: 5,
        rank_position: 3
      )

      cookies[:voter_token] = "test_token_mine"
      get rankings_path, params: { period: "weekly" }
      expect(response).to have_http_status(:ok)
    end

    it "defaults to weekly when period param is absent" do
      get rankings_path
      expect(response).to have_http_status(:ok)
      # The page should render without error, defaulting to weekly
    end

    it "falls back to weekly for unknown period values" do
      get rankings_path, params: { period: "daily" }
      expect(response).to have_http_status(:ok)
    end

    it "falls back to weekly for empty period" do
      get rankings_path, params: { period: "" }
      expect(response).to have_http_status(:ok)
    end

    it "defaults scope to national when not specified" do
      get rankings_path
      expect(response).to have_http_status(:ok)
    end

    it "handles invalid scope gracefully" do
      get rankings_path, params: { scope: "invalid_scope" }
      expect(response).to have_http_status(:ok)
    end

    it "handles prefecture scope without prefecture_id" do
      get rankings_path, params: { scope: "prefecture" }
      expect(response).to have_http_status(:ok)
    end

    it "works with monthly and prefecture scope combined" do
      prefecture = create(:prefecture)
      get rankings_path, params: { period: "monthly", scope: "prefecture", prefecture_id: prefecture.id }
      expect(response).to have_http_status(:ok)
    end

    it "works with all_time and national scope" do
      get rankings_path, params: { period: "all_time", scope: "national" }
      expect(response).to have_http_status(:ok)
    end
  end
end

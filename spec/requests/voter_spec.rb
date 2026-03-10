require "rails_helper"

RSpec.describe "Voter", type: :request do
  describe "GET /voter/status" do
    it "renders without voter_token cookie" do
      get voter_status_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("まだ投票していません")
    end

    it "renders with voter_token but no votes" do
      get voter_status_path, headers: { "Cookie" => "voter_token=abc123def456" }
      # Token exists but no votes — still shows the status page
      expect(response).to have_http_status(:ok)
    end

    context "with votes" do
      let(:shop) { create(:shop) }
      let(:machine) { create(:machine_model) }
      let(:token) { "test_voter_token_1234" }

      before do
        ShopMachineModel.create!(shop: shop, machine_model: machine)
        create(:vote, shop: shop, machine_model: machine, voter_token: token, voted_on: Date.current, reset_vote: 1)
      end

      it "displays vote statistics" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("投票者#1234")
        expect(response.body).to include("累計投票")
        expect(response.body).to include("実績バッジ")
      end

      it "displays recent vote history with shop name" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(shop.name)
        expect(response.body).to include(machine.name)
      end

      it "shows first vote badge as earned" do
        get voter_status_path, headers: { "Cookie" => "voter_token=#{token}" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("初投票")
      end
    end
  end
end

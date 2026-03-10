require "rails_helper"

RSpec.describe "ShopRequests", type: :request do
  describe "GET /shop_requests/new" do
    it "renders the request form" do
      get new_shop_request_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("店舗追加リクエスト")
    end
  end

  describe "POST /shop_requests" do
    let!(:prefecture) { create(:prefecture) }

    it "creates a shop request with valid params" do
      expect {
        post shop_requests_path, params: {
          shop_request: {
            name: "新しい店舗",
            prefecture_id: prefecture.id,
            address: "東京都新宿区1-1-1"
          }
        }
      }.to change(ShopRequest, :count).by(1)

      expect(response).to redirect_to(new_shop_request_path)
      created = ShopRequest.last
      expect(created.name).to eq("新しい店舗")
      expect(created).to be_pending
      expect(created.voter_token).to be_present
    end

    it "rejects request without name" do
      expect {
        post shop_requests_path, params: {
          shop_request: {
            name: "",
            prefecture_id: prefecture.id
          }
        }
      }.not_to change(ShopRequest, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /shop_requests/:id" do
    it "shows the request status" do
      shop_request = create(:shop_request)
      get shop_request_path(shop_request)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(shop_request.name)
      expect(response.body).to include("審査待ち")
    end
  end
end

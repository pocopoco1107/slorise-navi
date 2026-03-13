require "rails_helper"

RSpec.describe "PlayRecords", type: :request do
  let(:shop) { create(:shop) }
  let(:machine) { create(:machine_model) }
  let(:voter_token) { "test_token_123" }

  describe "GET /play_records" do
    it "returns 200 even without pre-existing voter_token (auto-created)" do
      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 with voter_token cookie" do
      cookies[:voter_token] = voter_token
      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "displays records for the current month" do
      cookies[:voter_token] = voter_token
      PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 5000
      )

      get play_records_path
      expect(response).to have_http_status(:ok)
    end

    it "accepts month param" do
      cookies[:voter_token] = voter_token
      get play_records_path, params: { month: Date.current.strftime("%Y-%m") }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /play_records" do
    it "creates a record even without pre-existing voter_token (auto-created)" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            played_on: Date.current.to_s,
            result_amount: 3000
          }
        }
      }.to change(PlayRecord, :count).by(1)
    end

    it "creates a record with valid data" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            machine_model_id: machine.id,
            played_on: Date.current.to_s,
            result_amount: 3000
          }
        }
      }.to change(PlayRecord, :count).by(1)

      expect(response).to redirect_to(play_records_path(month: Date.current.strftime("%Y-%m")))
    end

    it "redirects to return_to when provided" do
      cookies[:voter_token] = voter_token

      post play_records_path, params: {
        play_record: {
          shop_id: shop.id,
          machine_model_id: machine.id,
          played_on: Date.current.to_s,
          result_amount: 5000
        },
        return_to: "/shops/test-shop"
      }

      expect(response).to redirect_to("/shops/test-shop")
    end

    it "redirects with alert for invalid data" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: "",
            result_amount: ""
          }
        }
      }.not_to change(PlayRecord, :count)

      expect(response).to redirect_to(play_records_path)
      expect(flash[:alert]).to be_present
    end

    it "rejects result_amount out of range" do
      cookies[:voter_token] = voter_token

      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: 9_999_999
          }
        }
      }.not_to change(PlayRecord, :count)
    end
  end

  describe "DELETE /play_records/:id" do
    it "deletes own record" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: -2000
      )

      expect {
        delete play_record_path(record)
      }.to change(PlayRecord, :count).by(-1)

      expect(response).to have_http_status(:redirect)
    end

    it "cannot delete another user's record" do
      cookies[:voter_token] = voter_token
      other_record = PlayRecord.create!(
        voter_token: "other_user_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      expect {
        delete play_record_path(other_record)
      }.not_to change(PlayRecord, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /play_records/:id" do
    it "updates own record" do
      cookies[:voter_token] = voter_token
      record = PlayRecord.create!(
        voter_token: voter_token,
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      patch play_record_path(record), params: {
        play_record: { result_amount: 5000 }
      }

      expect(response).to redirect_to(play_records_path(month: Date.current.strftime("%Y-%m")))
      expect(record.reload.result_amount).to eq(5000)
    end

    it "cannot update another user's record" do
      cookies[:voter_token] = voter_token
      other_record = PlayRecord.create!(
        voter_token: "other_user_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )

      expect {
        patch play_record_path(other_record), params: {
          play_record: { result_amount: 9999 }
        }
      }.not_to change { other_record.reload.result_amount }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /play_records with invalid parameters" do
    before { cookies[:voter_token] = voter_token }

    it "rejects future dates" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: (Date.current + 1.day).to_s,
            result_amount: 1000
          }
        }
      }.not_to change(PlayRecord, :count)

      expect(response).to redirect_to(play_records_path)
      expect(flash[:alert]).to include("未来")
    end

    it "rejects result_amount below -999,999" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: -1_000_000
          }
        }
      }.not_to change(PlayRecord, :count)
    end

    it "rejects result_amount above 999,999" do
      expect {
        post play_records_path, params: {
          play_record: {
            shop_id: shop.id,
            played_on: Date.current.to_s,
            result_amount: 1_000_000
          }
        }
      }.not_to change(PlayRecord, :count)
    end
  end

  describe "access without voter_token" do
    it "auto-creates voter_token and creates record for POST /play_records" do
      expect {
        post play_records_path, params: {
          play_record: { shop_id: shop.id, played_on: Date.current.to_s, result_amount: 1000 }
        }
      }.to change(PlayRecord, :count).by(1)
    end

    it "returns 404 for PATCH /play_records/:id with another user's record" do
      record = PlayRecord.create!(
        voter_token: "some_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )
      patch play_record_path(record), params: { play_record: { result_amount: 2000 } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for DELETE /play_records/:id with another user's record" do
      record = PlayRecord.create!(
        voter_token: "some_token",
        shop: shop,
        machine_model: machine,
        played_on: Date.current,
        result_amount: 1000
      )
      delete play_record_path(record)
      expect(response).to have_http_status(:not_found)
    end
  end
end

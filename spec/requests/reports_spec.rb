require "rails_helper"

RSpec.describe "Reports", type: :request do
  describe "POST /reports" do
    let(:comment) { create(:comment) }

    let(:valid_params) do
      {
        report: {
          reportable_type: "Comment",
          reportable_id: comment.id,
          reason: "spam"
        }
      }
    end

    it "creates a report with valid params" do
      expect {
        post reports_path, params: valid_params
      }.to change(Report, :count).by(1)
    end

    it "assigns voter_token from cookie" do
      cookies[:voter_token] = "report_test_token"
      post reports_path, params: valid_params
      expect(Report.last.voter_token).to eq("report_test_token")
    end

    it "rejects invalid reportable_type" do
      params = valid_params.deep_dup
      params[:report][:reportable_type] = "User"
      post reports_path, params: params
      expect(response).to have_http_status(:bad_request)
    end

    it "allows reporting a ShopReview" do
      review = create(:shop_review)
      expect {
        post reports_path, params: {
          report: { reportable_type: "ShopReview", reportable_id: review.id, reason: "spam" }
        }
      }.to change(Report, :count).by(1)
    end

    it "responds with turbo_stream when requested" do
      post reports_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("通報しました")
    end
  end
end

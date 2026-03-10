require "rails_helper"

RSpec.describe "Feedbacks", type: :request do
  describe "GET /feedbacks/new" do
    it "renders the feedback form" do
      get new_feedback_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ご意見・ご要望")
    end
  end

  describe "POST /feedbacks" do
    it "creates a feedback with valid params" do
      expect {
        post feedbacks_path, params: { feedback: { body: "新機種を追加してほしい", category: "feature_request" } }
      }.to change(Feedback, :count).by(1)

      expect(response).to redirect_to(new_feedback_path)
    end

    it "rejects feedback without body" do
      expect {
        post feedbacks_path, params: { feedback: { body: "", category: "feature_request" } }
      }.not_to change(Feedback, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end

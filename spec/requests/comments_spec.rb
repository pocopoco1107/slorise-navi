require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:shop) { create(:shop) }

  describe "POST /comments" do
    let(:valid_params) do
      {
        comment: {
          commentable_type: "Shop",
          commentable_id: shop.id,
          body: "いいお店です",
          target_date: Date.current.to_s,
          commenter_name: "匿名さん"
        }
      }
    end

    it "creates a comment with valid params" do
      expect {
        post comments_path, params: valid_params
      }.to change(Comment, :count).by(1)
    end

    it "assigns voter_token from cookie" do
      cookies[:voter_token] = "comment_test_token"
      post comments_path, params: valid_params
      expect(Comment.last.voter_token).to eq("comment_test_token")
    end

    it "uses default commenter_name when not provided" do
      params = valid_params.deep_dup
      params[:comment].delete(:commenter_name)
      post comments_path, params: params
      expect(Comment.last.commenter_name).to eq("名無し")
    end

    it "rejects invalid commentable_type" do
      params = valid_params.deep_dup
      params[:comment][:commentable_type] = "User"
      post comments_path, params: params
      expect(response).to have_http_status(:bad_request)
    end

    it "responds with turbo_stream when requested" do
      post comments_path, params: valid_params, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "redirects on HTML format" do
      post comments_path, params: valid_params
      expect(response).to have_http_status(:redirect)
    end

    it "fails with empty body" do
      params = valid_params.deep_dup
      params[:comment][:body] = ""
      post comments_path, params: params
      expect(response).to have_http_status(:redirect)
      expect(Comment.count).to eq(0)
    end
  end
end

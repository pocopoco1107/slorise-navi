require "rails_helper"

RSpec.describe "ShopReviews", type: :request do
  let(:shop) { create(:shop) }

  describe "POST /shops/:slug/reviews" do
    it "creates a new review" do
      expect {
        post shop_shop_reviews_path(shop.slug), params: {
          shop_review: {
            rating: 4,
            body: "良い店舗です",
            category: "atmosphere",
            reviewer_name: "テスター"
          }
        }
      }.to change(ShopReview, :count).by(1)
    end

    it "updates existing review from same voter" do
      # First review
      post shop_shop_reviews_path(shop.slug), params: {
        shop_review: {
          rating: 3,
          body: "まあまあ",
          category: "service"
        }
      }
      expect(ShopReview.count).to eq(1)

      # Update (same voter_token via cookie)
      post shop_shop_reviews_path(shop.slug), params: {
        shop_review: {
          rating: 5,
          body: "やっぱり最高！",
          category: "atmosphere"
        }
      }
      expect(ShopReview.count).to eq(1)
      review = ShopReview.last
      expect(review.rating).to eq(5)
      expect(review.body).to eq("やっぱり最高！")
    end

    it "rejects review without rating" do
      expect {
        post shop_shop_reviews_path(shop.slug), params: {
          shop_review: {
            body: "テスト"
          }
        }
      }.not_to change(ShopReview, :count)
    end

    it "rejects review without body" do
      expect {
        post shop_shop_reviews_path(shop.slug), params: {
          shop_review: {
            rating: 3,
            body: ""
          }
        }
      }.not_to change(ShopReview, :count)
    end

    it "rejects review with invalid rating" do
      expect {
        post shop_shop_reviews_path(shop.slug), params: {
          shop_review: {
            rating: 7,
            body: "テスト"
          }
        }
      }.not_to change(ShopReview, :count)
    end
  end

  # Reviews section removed from shop page (comments are sufficient)
  # POST endpoint for reviews still works for backward compatibility
end

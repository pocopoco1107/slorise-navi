class ShopReviewsController < ApplicationController
  before_action :set_shop

  def create
    @review = @shop.shop_reviews.find_or_initialize_by(voter_token: voter_token)
    @review.assign_attributes(review_params)

    if @review.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to shop_path(@shop.slug), notice: "レビューを投稿しました" }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("review_form_errors", partial: "shop_reviews/form_errors", locals: { review: @review }) }
        format.html { redirect_to shop_path(@shop.slug), alert: @review.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def set_shop
    @shop = Shop.find_by!(slug: params[:shop_slug])
  end

  def review_params
    params.require(:shop_review).permit(:rating, :title, :body, :category, :reviewer_name)
  end
end

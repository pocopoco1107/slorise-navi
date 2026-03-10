require "rails_helper"

RSpec.describe Feedback, type: :model do
  it "is valid with body and category" do
    feedback = Feedback.new(body: "機能追加してほしい", category: :feature_request)
    expect(feedback).to be_valid
  end

  it "requires body" do
    feedback = Feedback.new(category: :feature_request)
    expect(feedback).not_to be_valid
  end

  it "limits body to 1000 characters" do
    feedback = Feedback.new(body: "a" * 1001, category: :feature_request)
    expect(feedback).not_to be_valid
  end

  it "has category labels" do
    feedback = Feedback.new(category: :shop_request)
    expect(feedback.category_label).to eq("店舗追加リクエスト")
  end
end

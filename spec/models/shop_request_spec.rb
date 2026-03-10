require "rails_helper"

RSpec.describe ShopRequest, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      shop_request = build(:shop_request)
      expect(shop_request).to be_valid
    end

    it "requires name" do
      shop_request = build(:shop_request, name: nil)
      expect(shop_request).not_to be_valid
      expect(shop_request.errors[:name]).to include("を入力してください")
    end

    it "requires voter_token" do
      shop_request = build(:shop_request, voter_token: nil)
      expect(shop_request).not_to be_valid
    end

    it "rejects name longer than 100 characters" do
      shop_request = build(:shop_request, name: "a" * 101)
      expect(shop_request).not_to be_valid
    end

    it "rejects note longer than 500 characters" do
      shop_request = build(:shop_request, note: "a" * 501)
      expect(shop_request).not_to be_valid
    end
  end

  describe "duplicate pending check" do
    it "rejects duplicate pending request for same prefecture and name" do
      pref = create(:prefecture)
      create(:shop_request, prefecture: pref, name: "テスト店舗", status: :pending)
      dup = build(:shop_request, prefecture: pref, name: "テスト店舗", status: :pending)

      expect(dup).not_to be_valid
      expect(dup.errors[:base]).to include("同じ都道府県・店舗名の申請がすでに審査待ちです")
    end

    it "allows same name if previous request was approved" do
      pref = create(:prefecture)
      create(:shop_request, prefecture: pref, name: "テスト店舗", status: :approved)
      new_req = build(:shop_request, prefecture: pref, name: "テスト店舗", status: :pending)

      expect(new_req).to be_valid
    end
  end

  describe "daily limit" do
    it "limits to 3 requests per day per voter_token" do
      pref = create(:prefecture)
      token = "test-token-123"

      3.times do |i|
        create(:shop_request, voter_token: token, prefecture: pref, name: "店舗#{i}")
      end

      fourth = build(:shop_request, voter_token: token, prefecture: pref, name: "店舗4")
      expect(fourth).not_to be_valid
      expect(fourth.errors[:base].first).to include("1日の申請上限")
    end
  end

  describe "enum" do
    it "defaults to pending" do
      shop_request = ShopRequest.new
      expect(shop_request.status).to eq("pending")
    end

    it "supports approved and rejected" do
      shop_request = create(:shop_request)
      shop_request.update!(status: :approved)
      expect(shop_request).to be_approved

      shop_request.update!(status: :rejected)
      expect(shop_request).to be_rejected
    end
  end
end

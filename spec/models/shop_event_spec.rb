require 'rails_helper'

RSpec.describe ShopEvent, type: :model do
  subject { build(:shop_event) }

  describe "validations" do
    it { is_expected.to be_valid }

    it "requires event_date" do
      subject.event_date = nil
      expect(subject).not_to be_valid
    end

    it "requires title" do
      subject.title = nil
      expect(subject).not_to be_valid
    end

    it "requires voter_token for user-submitted events" do
      subject.voter_token = nil
      subject.source = "user"
      expect(subject).not_to be_valid
    end

    it "allows nil voter_token for auto-collected events" do
      subject.voter_token = nil
      subject.source = "ptown"
      expect(subject).to be_valid
    end

    it "rejects event_date more than 60 days in the future for user events" do
      subject.event_date = Date.current + 61.days
      subject.source = "user"
      expect(subject).not_to be_valid
      expect(subject.errors[:event_date]).to be_present
    end

    it "rejects event_date more than 30 days in the past for user events" do
      subject.event_date = Date.current - 31.days
      subject.source = "user"
      expect(subject).not_to be_valid
      expect(subject.errors[:event_date]).to be_present
    end

    it "allows event_date within range" do
      subject.event_date = Date.current + 30.days
      expect(subject).to be_valid
    end

    it "skips date range validation for auto-collected events" do
      event = build(:shop_event, :auto_collected, event_date: Date.current - 60.days)
      expect(event).to be_valid
    end
  end

  describe "scopes" do
    let!(:shop) { create(:shop) }
    let!(:upcoming_event) { create(:shop_event, :approved, :upcoming, shop: shop) }
    let!(:past_event) { create(:shop_event, :approved, :past, shop: shop) }
    let!(:pending_event) { create(:shop_event, shop: shop) }

    it ".visible returns only approved events" do
      expect(ShopEvent.visible).to include(upcoming_event, past_event)
      expect(ShopEvent.visible).not_to include(pending_event)
    end

    it ".upcoming returns future events" do
      expect(ShopEvent.upcoming).to include(upcoming_event)
      expect(ShopEvent.upcoming).not_to include(past_event)
    end

    it ".past returns past events" do
      expect(ShopEvent.past).to include(past_event)
      expect(ShopEvent.past).not_to include(upcoming_event)
    end
  end

  describe "#event_type_label" do
    it "returns Japanese label" do
      subject.event_type = :filming
      expect(subject.event_type_label).to eq("取材")
    end
  end

  describe "#upcoming?" do
    it "returns true for future events" do
      subject.event_date = Date.current + 1.day
      expect(subject.upcoming?).to be true
    end

    it "returns false for past events" do
      subject.event_date = Date.current - 1.day
      expect(subject.upcoming?).to be false
    end
  end
end

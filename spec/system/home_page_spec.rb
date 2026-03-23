require "rails_helper"

RSpec.describe "Home page", type: :system do
  let!(:tokyo) { create(:prefecture, name: "東京都", slug: "tokyo") }
  let!(:osaka) { create(:prefecture, name: "大阪府", slug: "osaka") }
  let!(:shop) { create(:shop, name: "テスト店舗X", slug: "test-shop-x", prefecture: tokyo) }

  describe "hero section" do
    it "displays the hero heading and stats" do
      visit root_path

      expect(page).to have_content("みんなの記録")
      expect(page).to have_content("設定が見えてくる")
      expect(page).to have_content("累計")
      expect(page).to have_content("今日")
    end
  end

  describe "search bar" do
    it "displays the search input" do
      visit root_path

      expect(page).to have_field(type: "search", placeholder: "店舗名で検索")
    end
  end

  describe "prefecture list" do
    it "displays the prefecture section with region groups" do
      visit root_path

      expect(page).to have_content("都道府県から探す")
      expect(page).to have_content("北海道・東北")
      expect(page).to have_content("関東")
      expect(page).to have_content("中部")
      expect(page).to have_content("近畿")
      expect(page).to have_content("中国")
      expect(page).to have_content("四国")
      expect(page).to have_content("九州・沖縄")
    end
  end

  describe "prefecture section" do
    it "displays prefecture grid" do
      visit root_path

      expect(page).to have_content("都道府県から探す")
    end
  end

  describe "weekly ranking section" do
    it "displays the weekly ranking card" do
      visit root_path

      expect(page).to have_content("今週の高設定ランキング")
    end
  end

  describe "voter status link" do
    it "displays a link to voter status" do
      visit root_path

      expect(page).to have_link(href: voter_status_path)
    end
  end
end

ActiveAdmin.register ShopRequest do
  menu priority: 4, label: "店舗追加リクエスト"

  actions :index, :show, :destroy

  scope :all
  scope :pending, default: true
  scope :approved
  scope :rejected

  index do
    selectable_column
    id_column
    column("都道府県") { |r| r.prefecture.name }
    column :name
    column("住所") { |r| truncate(r.address.to_s, length: 40) }
    column("ステータス") do |r|
      case r.status
      when "pending" then status_tag("審査待ち", class: "warning")
      when "approved" then status_tag("承認済み", class: "yes")
      when "rejected" then status_tag("却下", class: "no")
      end
    end
    column :created_at
    actions
  end

  show do
    attributes_table do
      row("都道府県") { |r| r.prefecture.name }
      row :name
      row :address
      row("URL") { |r| r.url.present? ? link_to(r.url, r.url, target: "_blank", rel: "noopener") : nil }
      row :note
      row :voter_token
      row("ステータス") do |r|
        case r.status
        when "pending" then status_tag("審査待ち", class: "warning")
        when "approved" then status_tag("承認済み", class: "yes")
        when "rejected" then status_tag("却下", class: "no")
        end
      end
      row :admin_note
      row :created_at
      row :updated_at
    end
  end

  # Approve action
  action_item :approve, only: :show do
    if resource.pending?
      link_to "承認する", approve_admin_shop_request_path(resource), method: :put,
        data: { confirm: "この店舗を登録しますか？" }
    end
  end

  member_action :approve, method: :put do
    shop = nil
    ActiveRecord::Base.transaction do
      resource.update!(status: :approved)
      slug = resource.name.parameterize.presence || "shop-#{resource.id}"
      slug = "#{slug}-#{resource.id}" if Shop.exists?(slug: slug)
      shop = Shop.create!(
        name: resource.name,
        prefecture: resource.prefecture,
        address: resource.address,
        slug: slug
      )
    end
    redirect_to admin_shop_request_path(resource),
      notice: "承認しました。店舗「#{shop.name}」(ID: #{shop.id}) を作成しました"
  end

  # Reject action
  action_item :reject, only: :show do
    if resource.pending?
      link_to "却下する", reject_admin_shop_request_path(resource), method: :get
    end
  end

  member_action :reject, method: :get do
    render plain: <<~HTML, content_type: "text/html"
      <!DOCTYPE html>
      <html>
      <head><title>却下理由</title></head>
      <body style="font-family: sans-serif; max-width: 500px; margin: 40px auto; padding: 20px;">
        <h2>却下理由を入力</h2>
        <p>店舗: #{resource.name} (#{resource.prefecture.name})</p>
        <form action="#{do_reject_admin_shop_request_path(resource)}" method="post">
          <input type="hidden" name="authenticity_token" value="#{form_authenticity_token}">
          <textarea name="admin_note" rows="4" style="width: 100%; padding: 8px; border: 1px solid #ccc; border-radius: 4px;" placeholder="却下理由（任意）"></textarea>
          <br><br>
          <button type="submit" style="background: #dc2626; color: white; padding: 8px 20px; border: none; border-radius: 4px; cursor: pointer;">却下する</button>
          <a href="#{admin_shop_request_path(resource)}" style="margin-left: 12px;">キャンセル</a>
        </form>
      </body>
      </html>
    HTML
  end

  member_action :do_reject, method: :post do
    resource.update!(status: :rejected, admin_note: params[:admin_note])
    redirect_to admin_shop_request_path(resource), notice: "却下しました"
  end

  # Batch actions
  batch_action :approve, confirm: "選択した申請を一括承認しますか？" do |ids|
    batch_action_collection.find(ids).each do |req|
      next unless req.pending?

      ActiveRecord::Base.transaction do
        req.update!(status: :approved)
        slug = req.name.parameterize.presence || "shop-#{req.id}"
        slug = "#{slug}-#{req.id}" if Shop.exists?(slug: slug)
        Shop.create!(
          name: req.name,
          prefecture: req.prefecture,
          address: req.address,
          slug: slug
        )
      end
    end
    redirect_to collection_path, notice: "#{ids.size}件を承認しました"
  end

  batch_action :reject, confirm: "選択した申請を一括却下しますか？" do |ids|
    batch_action_collection.find(ids).each do |req|
      next unless req.pending?
      req.update!(status: :rejected, admin_note: "一括却下")
    end
    redirect_to collection_path, notice: "#{ids.size}件を却下しました"
  end
end

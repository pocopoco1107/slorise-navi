ActiveAdmin.register Shop do
  permit_params :prefecture_id, :name, :address, :lat, :lng, :slug,
                :exchange_rate, :total_machines, :slot_machines,
                :business_hours, :holidays, :opened_on, :former_event_days, :notes,
                slot_rates: []

  index do
    selectable_column
    id_column
    column :name
    column :prefecture
    column("レート") { |s| s.slot_rates_display }
    column("換金率") { |s| s.exchange_rate_display }
    column :slot_machines
    column :address
    actions
  end

  filter :name
  filter :prefecture
  filter :exchange_rate, as: :select, collection: Shop.exchange_rates
  filter :address

  show do
    attributes_table do
      row :name
      row :prefecture
      row :address
      row :slug
      row("レート") { |s| s.slot_rates_display }
      row("換金率") { |s| s.exchange_rate_display }
      row :total_machines
      row :slot_machines
      row :business_hours
      row :holidays
      row :opened_on
      row :former_event_days
      row :notes
      row :lat
      row :lng
    end
  end

  form do |f|
    f.inputs "基本情報" do
      f.input :prefecture
      f.input :name
      f.input :address
      f.input :slug
      f.input :lat
      f.input :lng
    end
    f.inputs "店舗詳細" do
      f.input :slot_rates, as: :check_boxes, collection: Shop::SLOT_RATES
      f.input :exchange_rate, as: :select, collection: [["未設定", "unknown_rate"], ["等価", "equal_rate"], ["5.6枚交換", "rate_56"], ["5.0枚交換", "rate_50"], ["非等価", "non_equal"]]
      f.input :total_machines
      f.input :slot_machines
      f.input :business_hours, placeholder: "10:00〜22:45"
      f.input :holidays, placeholder: "年中無休"
      f.input :opened_on, as: :datepicker
      f.input :former_event_days, placeholder: "毎月7日, 17日, 27日"
      f.input :notes, as: :text
    end
    f.actions
  end
end

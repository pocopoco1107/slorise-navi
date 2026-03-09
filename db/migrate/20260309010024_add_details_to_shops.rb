class AddDetailsToShops < ActiveRecord::Migration[8.0]
  def change
    # レート (複数選択可能、配列型)
    add_column :shops, :slot_rates, :string, array: true, default: []

    # 換金率
    add_column :shops, :exchange_rate, :integer, default: 0

    # 台数
    add_column :shops, :total_machines, :integer
    add_column :shops, :slot_machines, :integer

    # 営業情報
    add_column :shops, :business_hours, :string
    add_column :shops, :holidays, :string, default: "年中無休"

    # オープン日
    add_column :shops, :opened_on, :date

    # 旧イベント日
    add_column :shops, :former_event_days, :string

    # 取材・来店情報メモ
    add_column :shops, :notes, :text

    # GINインデックス for array column
    add_index :shops, :slot_rates, using: :gin
  end
end

class AddSourceUrlIndexToSnsReports < ActiveRecord::Migration[8.0]
  def change
    add_index :sns_reports, :source_url, unique: true, where: "source_url IS NOT NULL"
    add_index :sns_reports, :source
  end
end

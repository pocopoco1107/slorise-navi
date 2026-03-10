class CreateFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :feedbacks do |t|
      t.string :name
      t.string :email
      t.integer :category, default: 0, null: false
      t.text :body, null: false
      t.string :voter_token
      t.integer :status, default: 0, null: false  # 0=unread, 1=read, 2=resolved

      t.timestamps
    end

    add_index :feedbacks, :status
  end
end

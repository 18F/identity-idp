class CreateEmailDataTable < ActiveRecord::Migration[7.0]
  def change
    enable_extension "citext"

    create_table :disposable_domains do |t|
      t.citext :name, null: false
    end

    add_index :disposable_domains, :name, unique: true
  end
end

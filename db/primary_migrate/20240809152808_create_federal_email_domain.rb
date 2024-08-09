class CreateFederalEmailDomain < ActiveRecord::Migration[7.1]
  def change
    create_table :federal_email_domains do |t|
      t.citext :name, null: false
    end

    add_index :federal_email_domains, :name, unique: true
  end
end

class AddDisposableEmailDomainsTable < ActiveRecord::Migration[7.1]
  def change
    enable_extension "citext"

    create_table :disposable_email_domains do |t|
      t.citext :name, null: false
    end

    add_index :disposable_email_domains, :name, unique: true
  end
end

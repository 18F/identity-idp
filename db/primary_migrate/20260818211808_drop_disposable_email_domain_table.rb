class DropDisposableEmailDomainTable < ActiveRecord::Migration[8.1]
  def change
    drop_table :disposable_email_domains, if_exists: true
  end
end

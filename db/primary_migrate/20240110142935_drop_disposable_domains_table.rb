class DropDisposableDomainsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :disposable_domains
  end
end

class AddDefaultAalToServiceProvider < ActiveRecord::Migration[6.1]
  def up
    add_column :service_providers, :default_aal, :integer
    ServiceProvider.all.each do |sp|
      sp.update!(default_aal: sp.aal) if sp.aal
    end
  end

  def down
    remove_column :service_providers, :default_aal
  end
end

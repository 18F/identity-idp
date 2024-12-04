class AddPostIdvFollowupUrlToServiceProvider < ActiveRecord::Migration[7.2]
  def change
    add_column :service_providers, :post_idv_followup_url, :string, comment: 'sensitive=false'
  end
end

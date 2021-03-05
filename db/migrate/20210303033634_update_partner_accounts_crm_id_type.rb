class UpdatePartnerAccountsCrmIdType < ActiveRecord::Migration[6.1]
  def change
    # the column is populated from the config so can just be overwritten
    safety_assured { remove_column :partner_accounts, :crm_id, :integer }
    add_column :partner_accounts, :crm_id, :bigint
  end
end

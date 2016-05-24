class RemoveIdvFieldsFromUser < ActiveRecord::Migration
  def change
    remove_column :users, :ial_token, :string
    remove_column :users, :idp_hard_fail, :boolean
    remove_column :users, :ial, :integer
  end
end

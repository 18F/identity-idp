class DropUserEmailPlain < ActiveRecord::Migration
  def change
    remove_column :users, :email_plain
  end
end

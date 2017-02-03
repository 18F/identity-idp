class AddCodeChallengeToIdentities < ActiveRecord::Migration
  def change
    add_column :identities, :code_challenge, :string
  end
end

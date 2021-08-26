class AddCodeChallengeToIdentities < ActiveRecord::Migration[4.2]
  def change
    add_column :identities, :code_challenge, :string
  end
end

class AddMfaPromptSkipAtToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :non_restricted_mfa_required_prompt_skip_date, :date
  end
end

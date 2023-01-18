class AddNonRestrictedMfaRequiredPromptSkipDateToUser < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :non_restricted_mfa_required_prompt_skip_date, :date
  end
end

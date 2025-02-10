class DropUserMfaRequiredPromptSkipDate < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :users, :non_restricted_mfa_required_prompt_skip_date, :date }
  end
end

class AddAllowPromptToServiceProviders < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :allow_prompt, :boolean
    change_column_default :service_providers, :allow_prompt, false
  end

  def down
    remove_column :service_providers, :allow_prompt
  end
end

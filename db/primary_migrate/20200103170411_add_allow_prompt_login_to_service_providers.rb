class AddAllowPromptLoginToServiceProviders < ActiveRecord::Migration[5.1]
  def up
    add_column :service_providers, :allow_prompt_login, :boolean
    change_column_default :service_providers, :allow_prompt_login, false
  end

  def down
    remove_column :service_providers, :allow_prompt_login
  end
end

class CreateHelpTexts < ActiveRecord::Migration[5.1]
  def change
    create_table :help_texts do |t|
      t.belongs_to :service_provider, index: true
      t.string :sign_in
      t.string :sign_up
      t.string :forgot_password

      t.timestamps
    end
  end
end

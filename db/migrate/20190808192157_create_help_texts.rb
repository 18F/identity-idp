class CreateHelpTexts < ActiveRecord::Migration[5.1]
  def up
    create_table :help_texts do |t|
      t.belongs_to :service_provider, index: true
      t.json :sign_in, default: {}
      t.json :sign_up, default: {}
      t.json :forgot_password, default: {}
      t.timestamps
    end

    ServiceProvider.all.each do |sp|
      sp.help_text = HelpText.new
    end
  end

  def down
    drop_table :help_texts
  end
end

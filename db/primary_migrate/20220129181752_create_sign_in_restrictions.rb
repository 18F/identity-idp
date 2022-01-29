class CreateSignInRestrictions < ActiveRecord::Migration[6.1]
  def change
    create_table :sign_in_restrictions do |t|
      t.integer :user_id, null: false
      t.string :service_provider

      t.timestamps
    end

    add_index(
      :sign_in_restrictions,
      [:user_id, :service_provider],
      unique: true,
      name: :index_sign_in_restrictions_on_user_id_and_service_provider,
    )
  end
end

class AddLivenessEnabledFieldsToDocCaptures < ActiveRecord::Migration[5.2]
  def change
    add_column :doc_captures, :ial2_strict, :boolean
    add_column :doc_captures, :issuer, :string
  end
end

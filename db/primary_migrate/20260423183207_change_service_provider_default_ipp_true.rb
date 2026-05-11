# frozen_string_literal: true

class ChangeServiceProviderDefaultIppTrue < ActiveRecord::Migration[8.0]
  def change
    change_column_default(:service_providers, :in_person_proofing_enabled, from: false, to: true)
  end
end

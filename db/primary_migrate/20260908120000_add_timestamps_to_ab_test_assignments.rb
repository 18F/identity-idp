# frozen_string_literal: true

class AddTimestampsToAbTestAssignments < ActiveRecord::Migration[8.0]
  def change
    add_timestamps :ab_test_assignments, null: true
    change_column_comment :ab_test_assignments, :created_at, from: nil, to: 'sensitive=false'
    change_column_comment :ab_test_assignments, :updated_at, from: nil, to: 'sensitive=false'
  end
end

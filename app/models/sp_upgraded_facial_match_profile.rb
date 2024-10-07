# frozen_string_literal: true

class SpUpgradedFacialMatchProfile < ApplicationRecord
  # table was created prior to the feature rename
  self.table_name = :sp_upgraded_biometric_profiles

  belongs_to :user
end

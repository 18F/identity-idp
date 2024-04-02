# frozen_string_literal: true

class AgencyIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :agency
  validates :uuid, presence: true
end

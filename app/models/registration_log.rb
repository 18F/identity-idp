# frozen_string_literal: true

class RegistrationLog < ApplicationRecord
  belongs_to :user
end

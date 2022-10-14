class RegistrationLog < ApplicationRecord
  self.ignored_columns = %w[
    submitted_at
    confirmed_at
    password_at
    first_mfa
    first_mfa_at
    second_mfa
  ]

  belongs_to :user
end

class SecurityEvent < ApplicationRecord
  CREDENTIAL_CHANGE_REQUIRED = 'https://schemas.openid.net/secevent/risc/event-type/account-credential-change-required'.freeze

  belongs_to :user
end

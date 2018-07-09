module TwoFactorAuthentication
  class VerifyForm
    include ActiveModel::Model

    attr_accessor :user, :configuration_manager

    validates :user, presence: true
    validates :configuration_manager, presence: true
  end
end

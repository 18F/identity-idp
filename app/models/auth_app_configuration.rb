class AuthAppConfiguration
  # This is a wrapping class that lets us interface with the auth app configuration in a manner
  # consistent with phone and webauthn configurations.
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def mfa_enabled?
    user&.otp_secret_key.present?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::AuthAppSelectionPresenter.new(self)]
    else
      []
    end
  end

  def friendly_name
    :auth_app
  end

  def self.selection_presenters(set)
    set.flat_map(&:selection_presenters)
  end
end

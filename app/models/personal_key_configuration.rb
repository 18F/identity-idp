class PersonalKeyConfiguration
  # This is a wrapping class that lets us interface with the personal key configuration in a
  # manner consistent with phone and webauthn configurations.
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def mfa_enabled?
    PersonalKeyLoginOptionPolicy.new(user).configured?
  end

  def selection_presenters
    if mfa_enabled?
      [TwoFactorAuthentication::PersonalKeySelectionPresenter.new(self)]
    else
      []
    end
  end
end

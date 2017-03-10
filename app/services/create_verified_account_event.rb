class CreateVerifiedAccountEvent
  def initialize(user)
    @user = user
  end

  def call
    create_account_verified_event
  end

  private

  def create_account_verified_event
    return if user_account_verified?
    Event.create(user: @user, event_type: :account_verified)
  end

  def user_account_verified?
    @user.events.account_verified.present?
  end
end

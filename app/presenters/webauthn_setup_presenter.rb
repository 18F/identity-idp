class WebauthnSetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user

  def initialize(current_user, user_fully_authenticated)
    @current_user = current_user
    @user_fully_authenticated = user_fully_authenticated
  end

  def step
    no_factors_enabled? ? '3' : '4'
  end

  def steps_visible?
    SignUpProgressPolicy.new(
      @current_user,
      @user_fully_authenticated,
    ).sign_up_progress_visible?
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end

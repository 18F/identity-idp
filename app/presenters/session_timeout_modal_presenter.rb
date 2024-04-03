# frozen_string_literal: true

class SessionTimeoutModalPresenter
  def initialize(user_fully_authenticated:)
    @user_fully_authenticated = user_fully_authenticated
  end

  def translation_scope
    if user_fully_authenticated?
      [:notices, :timeout_warning, :signed_in]
    else
      [:notices, :timeout_warning, :partially_signed_in]
    end
  end

  private

  attr_reader :user_fully_authenticated
  alias_method :user_fully_authenticated?, :user_fully_authenticated
end

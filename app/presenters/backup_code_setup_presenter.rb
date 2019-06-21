class BackupCodeSetupPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :user

  def initialize(current_user)
    @current_user = current_user
  end

  def step
    no_factors_enabled? ? '3' : '4'
  end

  private

  def no_factors_enabled?
    MfaPolicy.new(@current_user).no_factors_enabled?
  end
end

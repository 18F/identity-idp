class PhoneConfigurationPresenter
  include ActionView::Helpers::TranslationHelper

  attr_reader :phone_configuration, :view

  def initialize(phone_configuration, view)
    @phone_configuration = phone_configuration
    @view = view
  end

  def default_msg
    t('account.index.default') if
      @phone_configuration == @view.current_user.default_phone_configuration
  end
end

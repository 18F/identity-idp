PhoneConfigurationDecorator = Struct.new(:phone_configuration) do
  def default_number_message
    I18n.t('account.index.default') if
      phone_configuration == phone_configuration.user.default_phone_configuration
  end
end

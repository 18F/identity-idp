class ServiceProviderSessionDecorator
  def initialize(sp_name:)
    @sp_name = sp_name
  end

  def registration_heading
    I18n.t('headings.create_account_with_sp', sp: sp_name)
  end

  def registration_bullet_1
    I18n.t('devise.registrations.start.bullet_1_with_sp', sp: sp_name)
  end

  private

  attr_reader :sp_name
end

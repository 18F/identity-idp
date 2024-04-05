# frozen_string_literal: true

class PivCacRecommendedPresenter
  attr_reader :user
  def initialize(user)
    @user = user
  end

  def info
    if MfaPolicy.new(user).two_factor_enabled?
      I18n.t('two_factor_authentication.piv_cac_upsell.existing_user_info', email_type: email_type)
    else
      I18n.t('two_factor_authentication.piv_cac_upsell.new_user_info', email_type: email_type)
    end
  end

  def email_type
    address = user.confirmed_email_addresses.find { |address| address.gov_or_mil? }
    case address.email.end_with?('.gov')
    when true
      '.gov'
    else
      '.mil'
    end
  end

  def skip_text
    if MfaPolicy.new(user).two_factor_enabled?
      I18n.t('two_factor_authentication.piv_cac_upsell.skip')
    else
      I18n.t('two_factor_authentication.piv_cac_upsell.choose_other_method')
    end
  end
end

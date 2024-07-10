# frozen_string_literal: true

class PivCacRecommendedPresenter
  attr_reader :user
  def initialize(user)
    @user = user
  end

  def skip_text
    if MfaPolicy.new(user).two_factor_enabled?
      I18n.t('two_factor_authentication.piv_cac_upsell.skip')
    else
      I18n.t('two_factor_authentication.piv_cac_upsell.choose_other_method')
    end
  end
end

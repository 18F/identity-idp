# These methods are temporary until we convert to using configuration managers. This cleans up
# the User model.
module UserDeprecatedMethods
  extend ActiveSupport::Concern

  def confirm_piv_cac?(proposed_uuid)
    two_factor_method_manager.configuration_manager(:piv_cac).authenticate(proposed_uuid)
  end

  def piv_cac_enabled?
    two_factor_method_manager.configuration_manager(:piv_cac).enabled?
  end

  def piv_cac_available?
    two_factor_method_manager.configuration_manager(:piv_cac).available?
  end

  def phone_enabled?
    two_factor_method_manager.two_factor_enabled?(%i[sms voice])
  end
end

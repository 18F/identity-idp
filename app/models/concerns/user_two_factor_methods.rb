module UserTwoFactorMethods
  extend ActiveSupport::Concern

  METHODS = %i[sms voice totp piv_cac personal_key].freeze

  # These queries will go away as we work on the 2fa refactoring
  def confirm_piv_cac?(proposed_uuid)
    two_factor_configuration(:piv_cac).authenticate(proposed_uuid)
  end

  def piv_cac_enabled?
    two_factor_configuration(:piv_cac).enabled?
  end

  def piv_cac_available?
    two_factor_configuration(:piv_cac).available?
  end

  def phone_enabled?
    two_factor_enabled?(%i[sms voice])
  end

  ##
  # @return [Array<TwoFactorAuthentication::MethodConfiguration>]
  #
  def two_factor_configurations
    two_factor_methods.map(&method(:two_factor_configuration))
  end

  ##
  # @param desired_methods [Array<Atom|String>]
  # @return [True|False]
  #
  def two_factor_enabled?(desired_methods = %i[sms voice totp piv_cac])
    desired_methods = two_factor_methods unless desired_methods&.any?
    (two_factor_methods & desired_methods).any? do |method|
      two_factor_configuration(method).enabled?
    end
  end

  ##
  # @param desired_methods [Array<Atom|String>]
  # @return [True|False]
  #
  def two_factor_configurable?(desired_methods = [])
    desired_methods = two_factor_methods unless desired_methods&.any?
    (two_factor_methods & desired_methods).any? do |method|
      two_factor_configuration(method).configurable?
    end
  end

  # Eventually, we'll allow multiple selection presenters for a single method if
  # that method supports multiple configurations. We really want one presenter per
  # configuration for configured/enabled setups and one presenter per method for
  # configurable methods.

  ##
  # @return [Array<TwoFactorAuthentication::MethodConfiguration>]
  #
  def two_factor_configurable_method_configurations
    promote_preferred(two_factor_configurations.select(&:configurable?))
  end

  ##
  # @return TwoFactorAuthentication::MethodConfiguration
  #
  def two_factor_configuration(method)
    class_constant(method, 'Configuration')&.new(user: self)
  end

  private

  def promote_preferred(set)
    preferred = set.detect(&:preferred?)
    if preferred
      [preferred] + (set - [preferred])
    else
      set
    end
  end

  def class_constant(method, suffix)
    ('TwoFactorAuthentication::' + method.to_s.camelcase + suffix).safe_constantize
  end

  def two_factor_methods
    METHODS
  end
end

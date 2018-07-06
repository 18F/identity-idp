module TwoFactorAuthentication
  class MethodManager
    attr_reader :user

    METHODS = %i[sms voice totp piv_cac personal_key].freeze

    ##
    # @param user [User]
    #
    def initialize(user)
      @user = user
    end

    def configuration_managers
      methods.map(&method(:configuration_manager))
    end

    ##
    # @param desired_methods [Array<Atom|String>]
    # @return [True|False]
    #
    def two_factor_enabled?(desired_methods = [])
      desired_methods = methods unless desired_methods&.any?
      (methods & desired_methods).any? do |method|
        configuration_manager(method).enabled?
      end
    end

    ##
    # @param desired_methods [Array<Atom|String>]
    # @return [True|False]
    #
    def two_factor_configurable?(desired_methods = [])
      desired_methods = methods unless desired_methods&.any?
      (methods & desired_methods).any? do |method|
        configuration_manager(method).configurable?
      end
    end

    ##
    # List configuration managers for all configurable 2FA methods for the
    # user. Used when presenting the user with a list of options during setup.
    #
    # For now, this methods returns at most one configuration manager per
    # 2FA method. This shouldn't change when we support multiple configurations
    # for some 2FA methods.
    #
    # @return [Array<TwoFactorAuthentication::ConfigurationManager>]
    #
    def configurable_configuration_managers
      promote_preferred(configuration_managers.select(&:configurable?))
    end

    ##
    # Create a configuration manager for the given method.
    #
    # @param method [Atom|String]
    # @return [TwoFactorAuthentication::ConfigurationManager]
    #
    def configuration_manager(method)
      class_constant(method, 'ConfigurationManager')&.new(user)
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

    def methods
      METHODS
    end
  end
end

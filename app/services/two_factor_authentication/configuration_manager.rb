module TwoFactorAuthentication
  class ConfigurationManager
    attr_reader :user

    def initialize(current_user)
      @user = current_user
    end

    # The default is that we can configure the method if it isn't already
    # configurable. `#configured?` isn't defined here.
    def configurable?
      !configured? && available?
    end

    def preferred?
      false
    end

    def method
      @method ||= begin
        self.class.name.demodulize.sub(/ConfigurationManager$/, '').snakecase.to_sym
      end
    end

    ##
    # Create a setup form appropriate for the 2FA method.
    #
    # Data is passed to the form with this object as `configuration_manager` and
    # the user as `user`.
    #
    # @param data [Hash]
    # @return [TwoFactorAuthentication::SetupForm]
    #
    def setup_form(data = {})
      class_constant('SetupForm')&.new(
        data.merge(
          user: user,
          configuration_manager: self
        )
      )
    end

    ##
    # Create a verification form appropriate for the 2FA method.
    #
    # Data is passed to the form with this object as `configuration_manager` and
    # the user as `user`.
    #
    # @param data [Hash]
    # @return [TwoFactorAuthentication::VerifyForm]
    #
    def verify_form(data = {})
      class_constant('VerifyForm')&.new(
        data.merge(
          user: user,
          configuration_manager: self
        )
      )
    end

    private

    def class_constant(suffix)
      ('TwoFactorAuthentication::' + method.to_s.camelcase + suffix).safe_constantize
    end
  end
end

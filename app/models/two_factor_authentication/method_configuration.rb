module TwoFactorAuthentication
  class MethodConfiguration
    attr_reader :user

    def initialize(user:)
      @user = user
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
        self.class.name.demodulize.sub(/Configuration$/, '').snakecase.to_sym
      end
    end
  end
end

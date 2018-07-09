module TwoFactorAuthentication
  class ConfigurationManager
    include Rails.application.routes.url_helpers

    attr_reader :user

    def initialize(current_user)
      @user = current_user
    end

    # The default is that we can configure the method if it isn't already
    # configured. `#configured?` isn't defined here.
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

    def selection_presenter
      class_constant('SelectionPresenter')&.new(self)
    end

    private

    def class_constant(suffix)
      ('TwoFactorAuthentication::' + method.to_s.camelcase + suffix).safe_constantize
    end
  end
end

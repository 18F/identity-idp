module TwoFactorAuthentication
  class SetUpSelectionPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :user, :piv_cac_required, :phishing_resistant_required, :user_agent
    alias_method :piv_cac_required?, :piv_cac_required
    alias_method :phishing_resistant_required?, :phishing_resistant_required

    def initialize(user:, piv_cac_required:, phishing_resistant_required:, user_agent:)
      @user = user
      @piv_cac_required = piv_cac_required
      @phishing_resistant_required = phishing_resistant_required
      @user_agent = user_agent
    end

    def render_in(view_context, &block)
      view_context.capture(&block)
    end

    def type
      raise NotImplementedError
    end

    def label
      raise NotImplementedError
    end

    def info
      raise NotImplementedError
    end

    def phishing_resistant?
      raise NotImplementedError
    end

    def mfa_added_label
      if single_configuration_only?
        ''
      else
        "(#{mfa_configuration_description})"
      end
    end

    def visible?
      if piv_cac_required?
        type == :piv_cac
      elsif phishing_resistant_required?
        phishing_resistant?
      elsif desktop_only?
        browser.desktop?
      else
        true
      end
    end

    def recommended?
      false
    end

    def desktop_only?
      false
    end

    def single_configuration_only?
      false
    end

    def mfa_configuration_count
      0
    end

    def mfa_configuration_description
      return '' if mfa_configuration_count == 0
      if single_configuration_only?
        t('two_factor_authentication.two_factor_choice_options.no_count_configuration_added')
      else
        t(
          'two_factor_authentication.two_factor_choice_options.configurations_added',
          count: mfa_configuration_count,
        )
      end
    end

    def disabled?
      single_configuration_only? && mfa_configuration_count > 0
    end

    def browser
      @browser ||= BrowserCache.parse(user_agent)
    end

    private :piv_cac_required, :phishing_resistant_required
  end
end

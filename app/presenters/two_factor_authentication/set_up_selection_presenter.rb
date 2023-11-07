module TwoFactorAuthentication
  class SetUpSelectionPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :user

    def initialize(user:)
      @user = user
    end

    def render_in(view_context, &block)
      view_context.capture(&block)
    end

    def type
      method.to_s
    end

    def label
      raise "Unsupported setup method: #{type}"
    end

    def info
      raise "Unsupported setup method: #{type}"
    end

    def mfa_added_label
      if single_configuration_only?
        ''
      else
        "(#{mfa_configuration_description})"
      end
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
  end
end

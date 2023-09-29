module TwoFactorAuthentication
  class SignInSelectionPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :configuration, :user

    def initialize(user:, configuration:)
      @user = user
      @configuration = configuration
    end

    def render_in(view_context, &block)
      view_context.capture(&block)
    end

    def type
      method.to_s
    end

    def label
      raise "Unsupported login method: #{type}"
    end

    def info
      raise "Unsupported login method: #{type}"
    end

    def disabled?
      false
    end
  end
end

# frozen_string_literal: true

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
      raise NotImplementedError
    end

    def label
      raise NotImplementedError
    end

    def info
      raise NotImplementedError
    end

    def disabled?
      false
    end
  end
end

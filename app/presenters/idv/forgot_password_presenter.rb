module Idv
  class ForgotPasswordPresenter < FailurePresenter
    include ActionView::Helpers::TranslationHelper

    delegate :idv_review_path,
             :request,
             to: :view_context

    attr_reader :view_context

    def initialize(view_context:)
      super(:are_you_sure)
      @view_context = view_context
    end

    def title
      t('idv.forgot_password.modal_header')
    end

    def header
      t('idv.forgot_password.modal_header')
    end

    def cancellation_warnings
      [
        t('idv.forgot_password.warnings.warning_1'),
        t('idv.forgot_password.warnings.warning_2'),
      ]
    end

    def go_back_path
      idv_review_path
    end
  end
end

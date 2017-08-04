module Verify
  class Base
    include Rails.application.routes.url_helpers

    def initialize(error: nil, remaining_attempts:, idv_form:, timed_out: nil)
      @error = error
      @remaining_attempts = remaining_attempts
      @idv_form = idv_form
      @timed_out = timed_out
    end

    attr_reader :error, :remaining_attempts, :idv_form

    def mock_vendor_partial
      if FeatureManagement.no_pii_mode?
        'verify/sessions/no_pii_warning'
      else
        'shared/null'
      end
    end

    def title
      I18n.t("idv.titles.#{step_name}")
    end

    def modal_partial
      if error.present?
        'shared/modal_verification'
      else
        'shared/null'
      end
    end

    def warning_partial
      if error == 'warning'
        'shared/modal_verification_warning'
      else
        'shared/null'
      end
    end

    def message
      return html_paragraph(text: I18n.t("idv.modal.#{step_name}.timeout")) if timed_out?
      html_paragraph(text: I18n.t("idv.modal.#{step_name}.#{error}")) if error
    end

    def button
      if error == 'warning'
        helper.content_tag(
          :button, button_link_text, id: 'js-close-modal', class: button_css_classes
        )
      else
        helper.link_to button_link_text, verify_fail_path, class: button_css_classes
      end
    end

    def flash_message
      flash_heading = html_paragraph(
        text: I18n.t("idv.modal.#{step_name}.heading"), css_class: 'mb2 fs-20p'
      )
      flash_body = message
      flash_heading + flash_body + attempts
    end

    private

    def timed_out?
      @timed_out
    end

    def button_link_text
      I18n.t("idv.modal.button.#{error}")
    end

    def button_css_classes
      'btn btn-wide px2 py1 rounded-lg border bw2'
    end

    def attempts
      if error == 'warning'
        html_paragraph(text: I18n.t('idv.modal.attempts', count: remaining_attempts))
      else
        ''
      end
    end

    # rubocop:disable Rails/OutputSafety
    def html_paragraph(text:, css_class: '')
      html = helper.safe_join([text.html_safe])
      helper.content_tag(:p, html, class: css_class)
    end
    # rubocop:enable Rails/OutputSafety

    def helper
      ActionController::Base.helpers
    end
  end
end

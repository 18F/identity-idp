module Idv
  class SsnPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :sp_name, :ssn_form, :step_indicator_steps

    def initialize(sp_name:, ssn_form:, step_indicator_steps:)
      @sp_name = sp_name
      @ssn_form = ssn_form
      @step_indicator_steps = step_indicator_steps
    end

    def exit_text
      if sp_name.present?
        t('doc_auth.info.exit.with_sp', app_name: APP_NAME, sp_name: sp_name)
      else
        t('doc_auth.info.exit.without_sp')
      end
    end

    def updating_ssn?
      ssn_form.updating_ssn?
    end
  end
end

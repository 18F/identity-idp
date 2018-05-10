module Idv
  class SessionsNew < Idv::Base
    def step_name
      :sessions
    end

    def unsupported_jurisdiction_error(sp_name)
      return unless idv_form.unsupported_jurisdiction?
      return unless sp_name
      errors = idv_form.errors
      error_message = [
        I18n.t('idv.errors.unsupported_jurisdiction'),
        I18n.t('idv.errors.unsupported_jurisdiction_sp', sp_name: sp_name),
      ].join(' ')
      errors.delete(:state)
      errors.add(:state, error_message)
    end
  end
end

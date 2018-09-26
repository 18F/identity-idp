module Idv
  class UspsPresenter
    include Rails.application.routes.url_helpers

    attr_reader :current_user

    def initialize(current_user)
      @current_user = current_user
    end

    def title
      letter_already_sent? ? I18n.t('idv.titles.mail.resend') : I18n.t('idv.titles.mail.verify')
    end

    def button
      letter_already_sent? ? I18n.t('idv.buttons.mail.resend') : I18n.t('idv.buttons.mail.send')
    end

    def cancel_path
      return verify_account_path if user_completed_idv?

      idv_cancel_path
    end

    private

    def usps_mail_service
      @usps_mail_service ||= Idv::UspsMail.new(current_user)
    end

    def letter_already_sent?
      usps_mail_service.any_mail_sent?
    end

    def user_completed_idv?
      current_user.decorate.pending_profile?
    end
  end
end

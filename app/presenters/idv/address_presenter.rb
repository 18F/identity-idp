# frozen_string_literal: true

module Idv
  class AddressPresenter
    def initialize(idv_session:)
      @idv_session = idv_session
    end

    attr_reader :idv_session

    def address_title
      if idv_session.requested_letter
        I18n.t('titles.doc_auth.mailing_address')
      else
        I18n.t('titles.doc_auth.address')
      end
    end

    def address_info
      if idv_session.requested_letter
        I18n.t('doc_auth.info.mailing_address')
      else
        I18n.t('doc_auth.info.address')
      end
    end

    def form_button_text
      if idv_session.requested_letter
        I18n.t('forms.buttons.continue')
      else
        I18n.t('forms.buttons.submit.update')
      end
    end

    def address_line1_hint
      "#{I18n.t('forms.example')} 150 Calle A Apt 3"
    end

    def address_line2_hint
      "#{I18n.t('forms.example')} URB Las Gladiolas"
    end

    def city_hint
      "#{I18n.t('forms.example')} San Juan"
    end

    def zipcode_hint
      "#{I18n.t('forms.example')} 00926"
    end

    def hint_class
      ['display-none', 'puerto-rico-extras']
    end
  end
end

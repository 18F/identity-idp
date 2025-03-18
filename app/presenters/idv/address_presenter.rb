# frozen_string_literal: true

module Idv
  class AddressPresenter
    include ActionView::Helpers::TranslationHelper

    attr_reader :is_passport

    def initialize(is_passport: false)
      @is_passport = is_passport
    end

    def header
      if is_passport
        t('doc_auth.headings.passport.address')
      else
        t('doc_auth.headings.address')
      end
    end

    def header_note
      if is_passport
        t('doc_auth.headings.passport.note')
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

    def button_text
      if is_passport
        t('forms.buttons.continue')
      else
        t('forms.buttons.submit.update')
      end
    end
  end
end

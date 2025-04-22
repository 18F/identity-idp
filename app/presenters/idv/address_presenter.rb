# frozen_string_literal: true

module Idv
  class AddressPresenter
    def page_heading
      if update?
        I18n.t('doc_auth.headings.address_update')
      else
        I18n.t('doc_auth.headings.address')
      end
    end

    def update_or_continue_button
      if update?
        I18n.t('forms.buttons.submit.update')
      else
        I18n.t('forms.button.continue')
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

    private

    def update?
      true
    end
  end
end

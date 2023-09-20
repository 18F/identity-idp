module Idv
  class AddressPresenter
    def initialize(pii:)
      @pii = pii
    end

    def pii
      @pii
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

module Idv
  class AddressPresenter
    def initialize(pii:)
      @pii = pii
    end

    def puerto_rico_address?
      @pii[:state] == 'PR'
    end

    def pii
      @pii
    end

    def address_line1_hint
      I18n.t('forms.example') + ' 150 Calle A Apt 3' if puerto_rico_address?
    end

    def address_line2_hint
      I18n.t('forms.example') + ' URB Las Gladiolas' if puerto_rico_address?
    end

    def city_hint
      I18n.t('forms.example') + ' San Juan' if puerto_rico_address?
    end

    def zipcode_hint
      I18n.t('forms.example') + ' 00926' if puerto_rico_address?
    end
  end
end

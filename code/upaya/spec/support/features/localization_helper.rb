module Features
  module LocalizationHelper
    def invalid_mobile_message
      t('activerecord.errors.models.user.attributes.mobile.improbable_phone')
    end
  end
end

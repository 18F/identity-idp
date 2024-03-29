# frozen_string_literal: true

module TwoFactorAuthentication
  class PivCacEditPresenter
    include ActionView::Helpers::TranslationHelper

    def initialize; end

    def heading
      t('two_factor_authentication.piv_cac.edit_heading')
    end

    def nickname_field_label
      t('two_factor_authentication.piv_cac.nickname')
    end

    def rename_button_label
      t('two_factor_authentication.piv_cac.change_nickname')
    end

    def delete_button_label
      t('two_factor_authentication.piv_cac.delete')
    end

    def rename_success_alert_text
      t('two_factor_authentication.piv_cac.renamed')
    end

    def delete_success_alert_text
      t('two_factor_authentication.piv_cac.deleted')
    end
  end
end

class BackupCodeDepletedPresenter
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::TranslationHelper

  def title
    t('forms.backup_code.depleted_title')
  end

  def description
    t('forms.backup_code.depleted_desc')
  end

  def other_option_display
    false
  end

  def other_option_title
    nil
  end

  def other_option_path
    two_factor_options_path
  end

  def continue_bttn_prologue
    nil
  end

  def continue_bttn_title
    t('forms.buttons.continue')
  end

  def continue_bttn_class
    'btn btn-primary btn-wide'
  end
end

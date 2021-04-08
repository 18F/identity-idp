class BackupCodeDepletedPresenter
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

  def continue_bttn_prologue
    nil
  end
end

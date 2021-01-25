class BackupCodeCreatePresenter
  include ActionView::Helpers::TranslationHelper

  def title
    t('forms.backup_code.are_you_sure_title')
  end

  def description
    t('forms.backup_code.are_you_sure_desc')
  end

  def other_option_display
    true
  end

  def other_option_title
    t('forms.backup_code.are_you_sure_other_option')
  end

  def continue_bttn_prologue
    t('forms.backup_code.are_you_sure_continue_prologue')
  end

  def continue_bttn_title
    t('forms.backup_code.are_you_sure_continue')
  end

  def continue_bttn_class
    'btn btn-link'
  end
end

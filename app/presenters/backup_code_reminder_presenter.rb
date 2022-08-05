class BackupCodeReminderPresenter
  def title
    I18n.t('forms.backup_code.title')
  end

  def heading
    I18n.t('forms.backup_code_reminder.heading')
  end

  def body_info
    I18n.t('forms.backup_code_reminder.body_info')
  end

  def button
    I18n.t('forms.backup_code_reminder.have_codes')
  end

  def need_new_codes_link_text
    I18n.t('forms.backup_code_reminder.need_new_codes')
  end
end

class BackupCodeIntroPresenter
  include Rails.application.routes.url_helpers

  attr_reader :state

  STATE_CONFIG = {
    signing_up: {
      title: I18n.t('forms.backup_code.are_you_sure_title'),
      description: I18n.t('forms.backup_code.are_you_sure_desc'),
      other_option_display: true,
      other_option_title: I18n.t('forms.backup_code.depleted_other_option'),
      continue_bttn_prologue:  I18n.t('forms.backup_code.are_you_sure_continue_prologue'),
      continue_bttn_title: I18n.t('forms.backup_code.are_you_sure_continue'),
      continue_bttn_class: 'btn btn-link',
    },
    depleted: {
      title: I18n.t('forms.backup_code.depleted_title'),
      description: I18n.t('forms.backup_code.depleted_desc'),
      other_option_display: false,
      other_option_title: '',
      continue_bttn_prologue:  '',
      continue_bttn_title: I18n.t('forms.buttons.continue'),
      continue_bttn_class: 'btn btn-primary btn-wide',
    },
  }.freeze

  def initialize(state)
    @state = state
  end

  def title
    STATE_CONFIG.dig(state, :title)
  end

  def description
    STATE_CONFIG.dig(state, :description)
  end

  def other_option_display
    STATE_CONFIG.dig(state, :other_option_display)
  end

  def other_option_title
    STATE_CONFIG.dig(state, :other_option_title)
  end

  def other_option_path
    two_factor_options_path
  end

  def continue_title
    STATE_CONFIG.dig(state, :continue_title)
  end

  def continue_bttn_prologue
    STATE_CONFIG.dig(state, :continue_bttn_prologue)
  end

  def continue_bttn_title
    STATE_CONFIG.dig(state, :continue_bttn_title)
  end

  def continue_bttn_class
    STATE_CONFIG.dig(state, :continue_bttn_class)
  end
end

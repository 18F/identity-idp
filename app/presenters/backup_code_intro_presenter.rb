class BackupCodeIntroPresenter
  include Rails.application.routes.url_helpers

  attr_reader :state

  def state_config # rubocop:disable Metrics/MethodLength
    {
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
    }
  end

  def initialize(state)
    @state = state
  end

  def title
    state_config.dig(state, :title)
  end

  def description
    state_config.dig(state, :description)
  end

  def other_option_display
    state_config.dig(state, :other_option_display)
  end

  def other_option_title
    state_config.dig(state, :other_option_title)
  end

  def other_option_path
    two_factor_options_path
  end

  def continue_title
    state_config.dig(state, :continue_title)
  end

  def continue_bttn_prologue
    state_config.dig(state, :continue_bttn_prologue)
  end

  def continue_bttn_title
    state_config.dig(state, :continue_bttn_title)
  end

  def continue_bttn_class
    state_config.dig(state, :continue_bttn_class)
  end
end

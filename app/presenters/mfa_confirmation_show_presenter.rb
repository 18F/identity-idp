class MfaConfirmationShowPresenter
    include MfaSetupConcern
    include ActionView::Helpers::TranslationHelper
  
    def initialize(
      current_user:,
      final_path:,
    )
      @current_user = current_user
      @final_path = final_path
    end
  
    def next_path
      confirmation_path(final_path)
    end
    
  
    def heading
      t('titles.mfa_setup.first_authentication_method')
    end
  
    def intro
      t('headings.mfa_setup.first_authentication_method')
    end
  
    def nickname_label
      if @platform_authenticator
        t('forms.webauthn_platform_setup.nickname')
      else
        t('forms.webauthn_setup.nickname')
      end
    end
  
    def button_text
      if @platform_authenticator
        t('forms.webauthn_platform_setup.continue')
      else
        t('forms.webauthn_setup.continue')
      end
    end
  
    def setup_heading
      if @platform_authenticator
        t('forms.webauthn_platform_setup.instructions_title')
      else
        t('forms.webauthn_setup.instructions_title')
      end
    end
  
    def setup_instructions
      if @platform_authenticator
        t('forms.webauthn_platform_setup.instructions_text', app_name: APP_NAME)
      else
        t('forms.webauthn_setup.instructions_text', app_name: APP_NAME)
      end
    end

    private

    attr_reader :current_user, :final_path
  end
  
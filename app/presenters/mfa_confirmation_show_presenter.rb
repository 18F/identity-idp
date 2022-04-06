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
      t('multi_factor_authentication.cta')
    end

    private

    attr_reader :current_user, :final_path
  end
  
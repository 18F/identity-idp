module Devise
  class AccountTypeController < DeviseController
    before_action :confirm_two_factor_setup
    before_action :confirm_two_factor_authenticated
    before_action :confirm_security_questions_setup
    before_action :confirm_needs_account_type
    prepend_before_action :authenticate_scope!

    include ScopeAuthenticator

    def type
    end

    def set_type
      return prompt_to_select_account_type unless valid_account_type?

      return redirect_to users_type_confirm_path if unconfirmed_representative?

      success if resource.update(account_type: account_type_param)
    end

    def confirm_type
      resource.account_type = 'representative'
    end

    private

    def account_type_param
      params.require(:user).permit(:account_type)[:account_type]
    rescue
      return nil
    end

    def prompt_to_select_account_type
      flash[:error] = t('upaya.errors.no_account_type')
      render(:type)
    end

    def unconfirmed_representative?
      account_type_param == 'representative' && !params[:confirm]
    end

    def success
      redirect_to dashboard_index_path,
                  notice: t('upaya.notices.account_created',
                            date: (Time.current + 1.year).strftime('%B %d, %Y'))
    end

    def confirm_needs_account_type
      return unless resource.account_type
      flash[:error] = t('upaya.errors.cannot_change_account_type')
      redirect_to dashboard_index_url
    end

    def valid_account_type?
      User.account_types.keys.include?(account_type_param)
    end
  end
end

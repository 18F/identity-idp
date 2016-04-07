module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_before_action :verify_authenticity_token

    def saml
      authorize :omniauth_callback, :saml?

      begin
        @auth = Authorization.from_omniauth(auth_hash, current_user)
      rescue ActiveRecord::RecordInvalid
        logger.info $ERROR_INFO.message
      end

      return render_401 if @auth.blank?
      sign_in_and_redirect @auth.user
      set_flash_message(:notice, :success, kind: 'Enterprise ICAM') if is_navigational_format?
    end

    private

    def auth_hash
      request.env['omniauth.auth']
    end

    def pundit_user
      groups = auth_hash.extra.raw_info.multi('groups') || auth_hash.extra.raw_info['groups']
      UserContext.new(current_user, groups)
    end
  end
end

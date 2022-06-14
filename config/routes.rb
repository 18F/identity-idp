Rails.application.routes.draw do
  # Non i18n routes. Alphabetically sorted.
  get '/api/analytics-events' => 'analytics_events#index'
  get '/api/country-support' => 'country_support#index'
  get '/api/health' => 'health/health#index'
  get '/api/health/database' => 'health/database#index'
  get '/api/health/jobs' => 'health/health#index'
  get '/api/health/outbound' => 'health/outbound#index'
  get '/api/openid_connect/certs' => 'openid_connect/certs#index'
  post '/api/openid_connect/token' => 'openid_connect/token#create'
  match '/api/openid_connect/token' => 'openid_connect/token#options', via: :options
  get '/api/openid_connect/userinfo' => 'openid_connect/user_info#show'
  post '/api/risc/security_events' => 'risc/security_events#create'
  post '/api/irs_attempts_api/security_events' => 'api/irs_attempts_api#create'

  # SAML secret rotation paths
  SamlEndpoint.suffixes.each do |suffix|
    get "/api/saml/metadata#{suffix}" => 'saml_idp#metadata', format: false
    match "/api/saml/logout#{suffix}" => 'saml_idp#logout', via: %i[get post delete]
    match "/api/saml/remotelogout#{suffix}" => 'saml_idp#remotelogout', via: %i[get post]
    # JS-driven POST redirect route to preserve existing session
    post "/api/saml/auth#{suffix}" => 'saml_post#auth'
    # actual SAML handling POST route
    post "/api/saml/authpost#{suffix}" => 'saml_idp#auth'
    get "/api/saml/auth#{suffix}" => 'saml_idp#auth'
  end

  post '/api/service_provider' => 'service_provider#update'
  post '/api/verify/images' => 'idv/image_uploads#create'
  post '/api/logger' => 'frontend_log#create'

  get '/openid_connect/authorize' => 'openid_connect/authorization#index'
  get '/openid_connect/logout' => 'openid_connect/logout#index'

  get '/no_js/detect.css' => 'no_js#index', as: :no_js_detect_css

  # i18n routes. Alphabetically sorted.
  scope '(:locale)', locale: /#{I18n.available_locales.join('|')}/ do
    # Devise handles login itself. It's first in the chain to avoid a redirect loop during
    # authentication failure.
    # devise_for(
    #   :users,
    #   skip: %i[confirmations sessions registrations two_factor_authentication],
    #   controllers: { passwords: 'users/reset_passwords' },
    # )

    # Additional device controller routes.
    devise_for(
      :users,
      skip: %i[confirmations sessions registrations two_factor_authentication passwords],
    )

    devise_scope :user do
      get '/users/password/new' => 'users/reset_passwords#new', as: :new_user_password
      get '/users/password/edit' => 'users/reset_passwords#edit', as: :edit_user_password
      patch '/users/password' => 'users/reset_passwords#update', as: :user_password
      put '/users/password' => 'users/reset_passwords#update', as: nil
      post '/users/password' => 'users/reset_passwords#create', as: nil

      get '/account/forget_all_browsers' => 'users/forget_all_browsers#show', as: :forget_all_browsers
      delete '/account/forget_all_browsers' => 'users/forget_all_browsers#destroy'

      get '/account/service_providers/:sp_id/revoke' => 'users/service_provider_revoke#show',
          as: :service_provider_revoke
      delete '/account/service_providers/:sp_id/revoke' => 'users/service_provider_revoke#destroy'

      get '/' => 'users/sessions#new', as: :new_user_session
      get '/bounced' => 'users/sp_handoff_bounced#bounced'
      post '/' => 'users/sessions#create', as: :user_session
      get '/logout' => 'users/sessions#destroy', as: :destroy_user_session
      delete '/logout' => 'users/sessions#destroy'
      get '/active' => 'users/sessions#active'
      post '/sessions/keepalive' => 'users/sessions#keepalive'

      get '/login/piv_cac' => 'users/piv_cac_login#new'
      get '/login/piv_cac_error' => 'users/piv_cac_login#error'

      get '/login/present_piv_cac' => 'users/piv_cac_login#redirect_to_piv_cac_service'
      get '/login/password' => 'password_capture#new', as: :capture_password
      post '/login/password' => 'password_capture#create'

      get '/account_reset/request' => 'account_reset/request#show'
      post '/account_reset/request' => 'account_reset/request#create'
      get '/account_reset/cancel' => 'account_reset/cancel#show'
      post '/account_reset/cancel' => 'account_reset/cancel#create'
      get '/account_reset/confirm_request' => 'account_reset/confirm_request#show'
      get '/account_reset/delete_account' => 'account_reset/delete_account#show'
      delete '/account_reset/delete_account' => 'account_reset/delete_account#delete'
      get '/account_reset/confirm_delete_account' => 'account_reset/confirm_delete_account#show'
      get '/account_reset/pending' => 'account_reset/pending#show'
      get '/account_reset/pending/confirm' => 'account_reset/pending#confirm'
      post '/account_reset/pending/cancel' => 'account_reset/pending#cancel'

      get '/login/two_factor/options' => 'two_factor_authentication/options#index'
      post '/login/two_factor/options' => 'two_factor_authentication/options#create'

      get '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#show'
      post '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#create'
      get '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#show'
      post '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#create'
      get '/login/two_factor/piv_cac' => 'two_factor_authentication/piv_cac_verification#show'
      get '/login/two_factor/piv_cac/present_piv_cac' => 'two_factor_authentication/piv_cac_verification#redirect_to_piv_cac_service'
      get '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#show'
      get '/login/two_factor/webauthn_error' => 'two_factor_authentication/webauthn_verification#error'
      patch '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#confirm'
      get 'login/two_factor/backup_code' => 'two_factor_authentication/backup_code_verification#show'
      post 'login/two_factor/backup_code' => 'two_factor_authentication/backup_code_verification#create'
      get  '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#show',
           as: :login_two_factor, constraints: { otp_delivery_preference: /sms|voice/ }
      post '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#create',
           as: :login_otp, constraints: { otp_delivery_preference: /sms|voice/ }
      get '/login/two_factor/sms/:opt_out_uuid/opt_in' => 'two_factor_authentication/sms_opt_in#new',
          as: :login_two_factor_sms_opt_in
      post '/login/two_factor/sms/:opt_out_uuid/opt_in' => 'two_factor_authentication/sms_opt_in#create'

      get 'login/add_piv_cac/prompt' => 'users/piv_cac_setup_from_sign_in#prompt'
      post 'login/add_piv_cac/prompt' => 'users/piv_cac_setup_from_sign_in#decline'
      get 'login/add_piv_cac/success' => 'users/piv_cac_setup_from_sign_in#success'
      post 'login/add_piv_cac/success' => 'users/piv_cac_setup_from_sign_in#next'

      get '/reauthn' => 'mfa_confirmation#new', as: :user_password_confirm
      post '/reauthn' => 'mfa_confirmation#create', as: :reauthn_user_password
      get '/timeout' => 'users/sessions#timeout'
    end

    if IdentityConfig.store.enable_test_routes
      namespace :test do
        # Assertion granting test start + return.
        get '/saml/login' => 'saml_test#index'
        get '/saml' => 'saml_test#start'
        get '/saml/decode_assertion' => 'saml_test#start'
        post '/saml/decode_assertion' => 'saml_test#decode_response'
        post '/saml/decode_slo_request' => 'saml_test#decode_slo_request'
        get '/piv_cac_entry' => 'piv_cac_authentication_test_subject#new'
        post '/piv_cac_entry' => 'piv_cac_authentication_test_subject#create'

        get '/telephony' => 'telephony#index'
        delete '/telephony' => 'telephony#destroy'
        get '/push_notification' => 'push_notification#index'
        delete '/push_notification' => 'push_notification#destroy'

        get '/s3/:key' => 'fake_s3#show', as: :fake_s3
        put '/s3/:key' => 'fake_s3#update'
      end
    end

    get '/auth_method_confirmation' => 'mfa_confirmation#show'
    post '/auth_method_confirmation/skip' => 'mfa_confirmation#skip'

    # Non-devise-controller routes. Alphabetically sorted.
    get '/.well-known/openid-configuration' => 'openid_connect/configuration#index',
        as: :openid_connect_configuration
    get '/.well-known/risc-configuration' => 'risc/configuration#index',
        as: :risc_configuration

    get '/account' => 'accounts#show'
    get '/account/connected_accounts' => 'accounts/connected_accounts#show'
    get '/account/devices/:id/events' => 'events#show', as: :account_events
    get '/account/delete' => 'users/delete#show', as: :account_delete
    post '/account/delete' => 'users/delete#delete'
    get '/account/email_language' => 'users/email_language#show', as: :account_email_language
    patch '/account/email_language' => 'users/email_language#update'
    get '/account/history' => 'accounts/history#show'
    get '/account/reactivate/start' => 'reactivate_account#index', as: :reactivate_account
    put '/account/reactivate/start' => 'reactivate_account#update'
    get '/account/reactivate/verify_password' => 'users/verify_password#new', as: :verify_password
    put '/account/reactivate/verify_password' => 'users/verify_password#update', as: :update_verify_password
    get '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#new',
        as: :verify_personal_key
    post '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#create',
         as: :create_verify_personal_key
    get '/account/two_factor_authentication' => 'accounts/two_factor_authentication#show'

    get '/errors/service_provider_inactive' => 'users/service_provider_inactive#index',
        as: :sp_inactive_error
    get '/errors/vendor' => 'vendor_outage#show', as: :vendor_outage

    get '/events/disavow' => 'event_disavowal#new', as: :event_disavowal
    post '/events/disavow' => 'event_disavowal#create', as: :events_disavowal

    get '/rules_of_use' => 'users/rules_of_use#new'
    post '/rules_of_use' => 'users/rules_of_use#create'

    get '/piv_cac' => 'users/piv_cac_authentication_setup#new', as: :setup_piv_cac
    get '/piv_cac_error' => 'users/piv_cac_authentication_setup#error', as: :setup_piv_cac_error
    delete '/piv_cac' => 'users/piv_cac_authentication_setup#delete', as: :disable_piv_cac
    post '/present_piv_cac' => 'users/piv_cac_authentication_setup#submit_new_piv_cac', as: :submit_new_piv_cac

    get '/webauthn_setup' => 'users/webauthn_setup#new', as: :webauthn_setup
    patch '/webauthn_setup' => 'users/webauthn_setup#confirm'
    delete '/webauthn_setup' => 'users/webauthn_setup#delete'
    get '/webauthn_setup_delete' => 'users/webauthn_setup#show_delete'

    delete '/authenticator_setup' => 'users/totp_setup#disable', as: :disable_totp
    get '/authenticator_setup' => 'users/totp_setup#new'
    patch '/authenticator_setup' => 'users/totp_setup#confirm'

    get '/forgot_password' => 'forgot_password#show'

    get '/manage/password' => 'users/passwords#edit'
    patch '/manage/password' => 'users/passwords#update'

    get '/add/email' => 'users/emails#show'
    post '/add/email' => 'users/emails#add'
    get '/add/email/confirm' => 'users/email_confirmations#create', as: :add_email_confirmation
    get '/add/email/verify_email' => 'users/emails#verify', as: :add_email_verify_email
    post '/add/email/resend' => 'users/emails#resend'

    delete '/manage/email/:id' => 'users/emails#delete', as: :delete_email
    get '/manage/email/confirm_delete/:id' => 'users/emails#confirm_delete',
        as: :manage_email_confirm_delete

    get '/add/phone' => 'users/phones#add'
    post '/add/phone' => 'users/phones#create'
    get '/manage/phone/:id' => 'users/edit_phone#edit', as: :manage_phone
    match '/manage/phone/:id' => 'users/edit_phone#update', via: %i[patch put]
    delete '/manage/phone/:id' => 'users/edit_phone#destroy'
    get '/manage/personal_key' => 'users/personal_keys#show', as: :manage_personal_key
    post '/manage/personal_key' => 'users/personal_keys#update'

    get '/account/personal_key' => 'accounts/personal_keys#new', as: :create_new_personal_key
    post '/account/personal_key' => 'accounts/personal_keys#create'

    get '/otp/send' => 'users/two_factor_authentication#send_code'

    get '/authentication_methods_setup' => 'users/two_factor_authentication_setup#index'
    patch '/authentication_methods_setup' => 'users/two_factor_authentication_setup#create'
    get '/two_factor_options', to: redirect('/authentication_methods_setup')
    patch '/two_factor_options' => 'users/two_factor_authentication_setup#create'
    get '/second_mfa_setup' => 'users/mfa_selection#index'
    get '/second_mfa_setup/non_restricted' => 'users/mfa_selection#non_restricted'
    patch '/second_mfa_setup' => 'users/mfa_selection#update'
    get '/phone_setup' => 'users/phone_setup#index'
    patch '/phone_setup' => 'users/phone_setup#create'
    get '/aal3_required' => 'users/aal3#show'
    get '/users/two_factor_authentication' => 'users/two_factor_authentication#show',
        as: :user_two_factor_authentication # route name is used by two_factor_authentication gem
    get '/backup_code_refreshed' => 'users/backup_code_setup#refreshed'
    get '/backup_code_setup' => 'users/backup_code_setup#index'
    patch '/backup_code_setup' => 'users/backup_code_setup#create', as: :backup_code_create
    patch '/backup_code_continue' => 'users/backup_code_setup#continue'
    get '/backup_code_regenerate' => 'users/backup_code_setup#edit'
    get '/backup_code_download' => 'users/backup_code_setup#download'
    get '/backup_code_delete' => 'users/backup_code_setup#confirm_delete'
    get '/backup_code_create' => 'users/backup_code_setup#confirm_create'
    delete '/backup_code_delete' => 'users/backup_code_setup#delete'

    get '/piv_cac_delete' => 'users/piv_cac_setup#confirm_delete'
    get '/auth_app_delete' => 'users/totp_setup#confirm_delete'

    get '/profile', to: redirect('/account')
    get '/profile/reactivate', to: redirect('/account/reactivate')
    get '/profile/verify', to: redirect('/account/verify')

    post '/sign_up/create_password' => 'sign_up/passwords#create', as: :sign_up_create_password
    get '/sign_up/email/confirm' => 'sign_up/email_confirmations#create',
        as: :sign_up_create_email_confirmation
    get '/sign_up/enter_email' => 'sign_up/registrations#new', as: :sign_up_email
    post '/sign_up/enter_email' => 'sign_up/registrations#create', as: :sign_up_register
    get '/sign_up/enter_email/resend' => 'sign_up/email_resend#new', as: :sign_up_email_resend
    get '/sign_up/enter_password' => 'sign_up/passwords#new'
    get '/sign_up/verify_email' => 'sign_up/emails#show', as: :sign_up_verify_email
    get '/sign_up/completed' => 'sign_up/completions#show', as: :sign_up_completed
    post '/sign_up/completed' => 'sign_up/completions#update'
    get '/user_authorization_confirmation' => 'users/authorization_confirmation#new'
    post '/user_authorization_confirmation' => 'users/authorization_confirmation#create'
    match '/user_authorization_confirmation/reset' => 'users/authorization_confirmation#destroy', as: :reset_user_authorization, via: %i[put delete]
    get '/sign_up/cancel/' => 'sign_up/cancellations#new', as: :sign_up_cancel
    delete '/sign_up/cancel' => 'sign_up/cancellations#destroy', as: :sign_up_destroy

    get '/redirect/return_to_sp/cancel' => 'redirect/return_to_sp#cancel', as: :return_to_sp_cancel
    get '/redirect/return_to_sp/failure_to_proof' => 'redirect/return_to_sp#failure_to_proof', as: :return_to_sp_failure_to_proof
    get '/redirect/help_center' => 'redirect/help_center#show', as: :help_center_redirect

    match '/sign_out' => 'sign_out#destroy', via: %i[get post delete]

    get '/restricted' => 'banned_user#show', as: :banned_user

    scope '/verify', as: 'idv' do
      get '/' => 'idv#index'
      get '/activated' => 'idv#activated'
    end
    scope '/verify', module: 'idv', as: 'idv' do
      get '/come_back_later' => 'come_back_later#show'
      get '/personal_key' => 'personal_key#show'
      post '/personal_key' => 'personal_key#update'
      get '/forgot_password' => 'forgot_password#new'
      post '/forgot_password' => 'forgot_password#update'
      get '/otp_delivery_method' => 'otp_delivery_method#new'
      put '/otp_delivery_method' => 'otp_delivery_method#create'
      get '/phone' => 'phone#new'
      put '/phone' => 'phone#create'
      get '/phone/errors/warning' => 'phone_errors#warning'
      get '/phone/errors/jobfail' => 'phone_errors#jobfail'
      get '/phone/errors/failure' => 'phone_errors#failure'
      post '/phone/resend_code' => 'resend_otp#create', as: :resend_otp
      get '/phone_confirmation' => 'otp_verification#show', as: :otp_verification
      put '/phone_confirmation' => 'otp_verification#update', as: :nil
      get '/review' => 'review#new'
      put '/review' => 'review#create'
      get '/session/errors/warning' => 'session_errors#warning'
      get '/phone/errors/timeout' => 'phone_errors#timeout'
      get '/session/errors/failure' => 'session_errors#failure'
      get '/session/errors/ssn_failure' => 'session_errors#ssn_failure'
      get '/session/errors/exception' => 'session_errors#exception'
      get '/session/errors/throttled' => 'session_errors#throttled'
      delete '/session' => 'sessions#destroy'
      get '/cancel/' => 'cancellations#new', as: :cancel
      put '/cancel' => 'cancellations#update'
      delete '/cancel' => 'cancellations#destroy'
      get '/address' => 'address#new'
      post '/address' => 'address#update'
      get '/doc_auth' => 'doc_auth#index'
      get '/doc_auth/return_to_sp' => 'doc_auth#return_to_sp'
      get '/doc_auth/:step' => 'doc_auth#show', as: :doc_auth_step
      put '/doc_auth/:step' => 'doc_auth#update'
      get '/doc_auth/link_sent/poll' => 'capture_doc_status#show', as: :capture_doc_status
      get '/doc_auth/errors/no_camera' => 'doc_auth#no_camera'
      get '/capture_doc' => 'capture_doc#index'
      get '/capture-doc' => 'capture_doc#index',
          # sometimes underscores get messed up when linked to via SMS
          as: :capture_doc_dashes
      get '/capture_doc/return_to_sp' => 'capture_doc#return_to_sp'
      get '/capture_doc/:step' => 'capture_doc#show', as: :capture_doc_step
      put '/capture_doc/:step' => 'capture_doc#update'

      get '/in_person' => 'in_person#index'
      get '/in_person/:step' => 'in_person#show', as: :in_person_step
      put '/in_person/:step' => 'in_person#update'

      # deprecated routes
      get '/confirmations' => 'personal_key#show'
      post '/confirmations' => 'personal_key#update'
    end

    get '/verify/v2(/:step)' => 'verify#show', as: :idv_app
    get '/verify/v2/password_confirm/forgot_password' => 'verify#show', as: :idv_app_forgot_password

    namespace :api do
      post '/verify/v2/password_confirm' => 'verify/password_confirm#create'
      post '/verify/v2/password_reset' => 'verify/password_reset#create'
    end

    get '/account/verify' => 'idv/gpo_verify#index', as: :idv_gpo_verify
    post '/account/verify' => 'idv/gpo_verify#create'
    if FeatureManagement.enable_gpo_verification?
      scope '/verify', module: 'idv', as: 'idv' do
        get '/usps' => 'gpo#index', as: :gpo
        put '/usps' => 'gpo#create'
        post '/usps' => 'gpo#update'
      end
    end

    root to: 'users/sessions#new'
  end

  # Make sure any new routes are added above this line!
  # The line below will route all requests that aren't
  # defined route to the 404 page. Therefore, anything you put after this rule
  # will be ignored.
  match '*path', via: :all, to: 'pages#page_not_found'
end

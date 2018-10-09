Rails.application.routes.draw do
  # Non i18n routes. Alphabetically sorted.
  get '/api/health' => 'health/health#index'
  get '/api/health/database' => 'health/database#index'
  get '/api/openid_connect/certs' => 'openid_connect/certs#index'
  post '/api/openid_connect/token' => 'openid_connect/token#create'
  match '/api/openid_connect/token' => 'openid_connect/token#options', via: :options
  get '/api/openid_connect/userinfo' => 'openid_connect/user_info#show'
  get '/api/saml/metadata' => 'saml_idp#metadata'
  match '/api/saml/logout' => 'saml_idp#logout',
        via: %i[get post delete],
        as: :destroy_user_session
  match '/api/saml/auth' => 'saml_idp#auth', via: %i[get post]

  # SAML secret rotation paths
  if FeatureManagement.enable_saml_cert_rotation?
    suffix = SamlCertRotationManager.rotation_path_suffix
    get "/api/saml/metadata#{suffix}" => 'saml_idp#metadata'
    match "/api/saml/logout#{suffix}" => 'saml_idp#logout',
          via: %i[get post delete],
          as: "destroy_user_session#{suffix}"
    match "/api/saml/auth#{suffix}" => 'saml_idp#auth', via: %i[get post]
  end

  # Twilio Request URL for inbound SMS
  post '/api/sms/receive' => 'sms#receive'

  post '/api/service_provider' => 'service_provider#update'
  match '/api/voice/otp' => 'voice/otp#show',
        via: %i[get post],
        as: :voice_otp,
        defaults: { format: :xml }

  post '/api/usps_upload' => 'usps_upload#create'

  get '/openid_connect/authorize' => 'openid_connect/authorization#index'
  get '/openid_connect/logout' => 'openid_connect/logout#index'

  # i18n routes. Alphabetically sorted.
  scope '(:locale)', locale: /#{I18n.available_locales.join('|')}/ do
    # Devise handles login itself. It's first in the chain to avoid a redirect loop during
    # authentication failure.
    devise_for(
      :users,
      skip: %i[confirmations sessions registrations two_factor_authentication],
      controllers: { passwords: 'users/reset_passwords' }
    )

    # Additional device controller routes.
    devise_scope :user do
      get '/' => 'users/sessions#new', as: :new_user_session
      post '/' => 'users/sessions#create', as: :user_session
      get '/active' => 'users/sessions#active'

      get '/account_reset/request' => 'account_reset/request#show'
      post '/account_reset/request' => 'account_reset/request#create'
      get '/account_reset/cancel' => 'account_reset/cancel#show'
      post '/account_reset/cancel' => 'account_reset/cancel#create'
      get '/account_reset/confirm_request' => 'account_reset/confirm_request#show'
      get '/account_reset/delete_account' => 'account_reset/delete_account#show'
      delete '/account_reset/delete_account' => 'account_reset/delete_account#delete'
      get '/account_reset/confirm_delete_account' => 'account_reset/confirm_delete_account#show'
      post '/api/account_reset/send_notifications' => 'account_reset/send_notifications#update'

      get '/login/two_factor/options' => 'two_factor_authentication/options#index'
      post '/login/two_factor/options' => 'two_factor_authentication/options#create'

      get '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#show'
      post '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#create'
      get '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#show'
      post '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#create'
      get '/login/two_factor/piv_cac' => 'two_factor_authentication/piv_cac_verification#show'
      if FeatureManagement.webauthn_enabled?
        get '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#show'
        patch '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#confirm'
      end
      get  '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#show',
           as: :login_two_factor, constraints: { otp_delivery_preference: /sms|voice/ }
      post '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#create',
           as: :login_otp

      get '/reauthn' => 'mfa_confirmation#new', as: :user_password_confirm
      post '/reauthn' => 'mfa_confirmation#create', as: :reauthn_user_password
      get '/timeout' => 'users/sessions#timeout'
    end

    if Figaro.env.enable_test_routes == 'true'
      namespace :test do
        # Assertion granting test start + return.
        get '/saml' => 'saml_test#start'
        get '/saml/decode_assertion' => 'saml_test#start'
        post '/saml/decode_assertion' => 'saml_test#decode_response'
        post '/saml/decode_slo_request' => 'saml_test#decode_slo_request'
        get '/piv_cac_entry' => 'piv_cac_authentication_test_subject#new'
        post '/piv_cac_entry' => 'piv_cac_authentication_test_subject#create'
      end
    end

    # Non-devise-controller routes. Alphabetically sorted.
    get '/.well-known/openid-configuration' => 'openid_connect/configuration#index',
        as: :openid_connect_configuration

    get '/account' => 'accounts#show'
    get '/account/delete' => 'users/delete#show', as: :account_delete
    delete '/account/delete' => 'users/delete#delete'
    get '/account/reactivate/start' => 'reactivate_account#index', as: :reactivate_account
    put '/account/reactivate/start' => 'reactivate_account#update'
    get '/account/reactivate/verify_password' => 'users/verify_password#new', as: :verify_password
    put '/account/reactivate/verify_password' => 'users/verify_password#update', as: :update_verify_password
    get '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#new',
        as: :verify_personal_key
    post '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#create',
         as: :create_verify_personal_key
    get '/account_recovery_setup' => 'account_recovery_setup#index'

    get '/piv_cac' => 'users/piv_cac_authentication_setup#new', as: :setup_piv_cac
    delete '/piv_cac' => 'users/piv_cac_authentication_setup#delete', as: :disable_piv_cac
    get '/present_piv_cac' => 'users/piv_cac_authentication_setup#redirect_to_piv_cac_service', as: :redirect_to_piv_cac_service

    if FeatureManagement.webauthn_enabled?
      get '/webauthn_setup' => 'users/webauthn_setup#new', as: :webauthn_setup
      patch '/webauthn_setup' => 'users/webauthn_setup#confirm'
      delete '/webauthn_setup' => 'users/webauthn_setup#delete'
      get '/webauthn_setup_success' => 'users/webauthn_setup#success'
    end

    delete '/authenticator_setup' => 'users/totp_setup#disable', as: :disable_totp
    get '/authenticator_setup' => 'users/totp_setup#new'
    patch '/authenticator_setup' => 'users/totp_setup#confirm'
    get '/authenticator_start' => 'users/totp_setup#start'

    get '/forgot_password' => 'forgot_password#show'

    get '/manage/email' => 'users/emails#edit'
    match '/manage/email' => 'users/emails#update', via: %i[patch put]
    get '/manage/password' => 'users/passwords#edit'
    patch '/manage/password' => 'users/passwords#update'
    get '/manage/phone' => 'users/phones#edit'
    match '/manage/phone' => 'users/phones#update', via: %i[patch put]
    get '/manage/personal_key' => 'users/personal_keys#show', as: :manage_personal_key
    post '/account/personal_key' => 'users/personal_keys#create', as: :create_new_personal_key
    post '/manage/personal_key' => 'users/personal_keys#update'

    get '/otp/send' => 'users/two_factor_authentication#send_code'
    get '/two_factor_options' => 'users/two_factor_authentication_setup#index'
    patch '/two_factor_options' => 'users/two_factor_authentication_setup#create'
    get '/phone_setup' => 'users/phone_setup#index'
    patch '/phone_setup' => 'users/phone_setup#create'
    get '/users/two_factor_authentication' => 'users/two_factor_authentication#show',
        as: :user_two_factor_authentication # route name is used by two_factor_authentication gem

    get '/profile', to: redirect('/account')
    get '/profile/reactivate', to: redirect('/account/reactivate')
    get '/profile/verify', to: redirect('/account/verify')

    post '/sign_up/create_password' => 'sign_up/passwords#create', as: :sign_up_create_password
    get '/sign_up/email/confirm' => 'sign_up/email_confirmations#create',
        as: :sign_up_create_email_confirmation
    get '/sign_up/enter_email' => 'sign_up/registrations#new', as: :sign_up_email
    post '/sign_up/enter_email' => 'sign_up/registrations#create', as: :sign_up_register
    get '/sign_up/enter_email/resend' => 'sign_up/email_resend#new', as: :sign_up_email_resend
    post '/sign_up/enter_email/resend' => 'sign_up/email_resend#create',
         as: :sign_up_create_email_resend
    get '/sign_up/enter_password' => 'sign_up/passwords#new'
    get '/sign_up/personal_key' => 'sign_up/personal_keys#show'
    post '/sign_up/personal_key' => 'sign_up/personal_keys#update'
    get '/sign_up/start' => 'sign_up/registrations#show', as: :sign_up_start
    get '/sign_up/verify_email' => 'sign_up/emails#show', as: :sign_up_verify_email
    get '/sign_up/completed' => 'sign_up/completions#show', as: :sign_up_completed
    post '/sign_up/completed' => 'sign_up/completions#update'

    match '/sign_out' => 'sign_out#destroy', via: %i[get post delete]

    delete '/users' => 'users#destroy', as: :destroy_user

    if FeatureManagement.enable_identity_verification?
      scope '/verify', as: 'idv' do
        get '/' => 'idv#index'
        get '/activated' => 'idv#activated'
        get '/fail' => 'idv#fail'
      end
      scope '/verify', module: 'idv', as: 'idv' do
        get '/come_back_later' => 'come_back_later#show'
        get '/confirmations' => 'confirmations#show'
        post '/confirmations' => 'confirmations#update'
        get '/forgot_password' => 'forgot_password#new'
        post '/forgot_password' => 'forgot_password#update'
        get '/otp_delivery_method' => 'otp_delivery_method#new'
        put '/otp_delivery_method' => 'otp_delivery_method#create'
        get '/phone' => 'phone#new'
        put '/phone' => 'phone#create'
        get '/phone/failure/:reason' => 'phone#failure', as: :phone_failure
        post '/phone/resend_code' => 'resend_otp#create', as: :resend_otp
        get '/phone_confirmation' => 'otp_verification#show', as: :otp_verification
        put '/phone_confirmation' => 'otp_verification#update', as: :nil
        get '/review' => 'review#new'
        put '/review' => 'review#create'
        get '/session' => 'sessions#new'
        put '/session' => 'sessions#create'
        get '/session/success' => 'sessions#success'
        get '/session/failure/:reason' => 'sessions#failure', as: :session_failure
        delete '/session' => 'sessions#destroy'
        get '/jurisdiction' => 'jurisdiction#new'
        post '/jurisdiction' => 'jurisdiction#create'
        get '/jurisdiction/failure/:reason' => 'jurisdiction#failure', as: :jurisdiction_failure
        get '/cancel/' => 'cancellations#new', as: :cancel
        delete '/cancel' => 'cancellations#destroy'
        if FeatureManagement.doc_auth_enabled?
          get '/doc_auth' => 'doc_auth#index'
          get '/doc_auth/:step' => 'doc_auth#show', as: :doc_auth_step
          put '/doc_auth/:step' => 'doc_auth#update'
        end
      end
    end

    if FeatureManagement.enable_usps_verification?
      get '/account/verify' => 'users/verify_account#index', as: :verify_account
      post '/account/verify' => 'users/verify_account#create'
      scope '/verify', module: 'idv', as: 'idv' do
        get '/usps' => 'usps#index'
        put '/usps' => 'usps#create'
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

Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new

  # Non i18n routes. Alphabetically sorted.
  get '/api/health' => 'health/health#index'
  get '/api/health/database' => 'health/database#index'
  get '/api/health/workers' => 'health/workers#index'
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

  post '/api/service_provider' => 'service_provider#update'
  match '/api/voice/otp' => 'voice/otp#show',
        via: %i[get post],
        as: :voice_otp,
        defaults: { format: :xml }

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

      get '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#show'
      post '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#create'
      get '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#show'
      post '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#create'
      if FeatureManagement.piv_cac_enabled?
        get '/login/two_factor/piv_cac' => 'two_factor_authentication/piv_cac_verification#show'
      end
      get  '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#show',
           as: :login_two_factor
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
        if FeatureManagement.piv_cac_enabled?
          get '/piv_cac_entry' => 'piv_cac_authentication_test_subject#new'
          post '/piv_cac_entry' => 'piv_cac_authentication_test_subject#create'
        end
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
    get '/account/verify_phone' => 'users/verify_profile_phone#index', as: :verify_profile_phone
    post '/account/verify_phone' => 'users/verify_profile_phone#create'

    if FeatureManagement.piv_cac_enabled?
      get '/piv_cac' => 'users/piv_cac_authentication_setup#new', as: :setup_piv_cac
      delete '/piv_cac' => 'users/piv_cac_authentication_setup#delete', as: :disable_piv_cac
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
    get '/phone_setup' => 'users/two_factor_authentication_setup#index'
    patch '/phone_setup' => 'users/two_factor_authentication_setup#set'
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
        get '/cancel' => 'idv#cancel'
        get '/fail' => 'idv#fail'
      end
      scope '/verify', module: 'idv', as: 'idv' do
        get '/address' => 'address#index'
        post '/address' => 'address#create'
        get '/come_back_later' => 'come_back_later#show'
        get '/confirmations' => 'confirmations#show'
        post '/confirmations' => 'confirmations#update'
        get '/otp_delivery_method' => 'otp_delivery_method#new'
        put '/otp_delivery_method' => 'otp_delivery_method#create'
        get '/phone' => 'phone#new'
        put '/phone' => 'phone#create'
        get '/phone/result' => 'phone#show'
        get '/review' => 'review#new'
        put '/review' => 'review#create'
        get '/session' => 'sessions#new'
        put '/session' => 'sessions#create'
        get '/session/result' => 'sessions#show'
        delete '/session' => 'sessions#destroy'
        get '/session/dupe' => 'sessions#dupe'
        get '/jurisdiction' => 'jurisdiction#new'
        post '/jurisdiction' => 'jurisdiction#create'
        get '/jurisdiction/:reason' => 'jurisdiction#show', as: :jurisdiction_fail
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

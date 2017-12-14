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

  post '/api/service_provider' => 'service_provider#update'
  match '/api/voice/otp' => 'voice/otp#show',
        via: [:get, :post],
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
      end
    end

    # Non-devise-controller routes. Alphabetically sorted.
    get '/.well-known/openid-configuration' => 'openid_connect/configuration#index',
        as: :openid_connect_configuration

    get '/account' => 'accounts#show'
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
      get '/verify' => 'verify#index'
      get '/verify/activated' => 'verify#activated'
      get '/verify/address' => 'verify/address#index'
      post '/verify/address' => 'verify/address#create'
      get '/verify/cancel' => 'verify#cancel'
      get '/verify/come_back_later' => 'verify/come_back_later#show'
      get '/verify/confirmations' => 'verify/confirmations#show'
      post '/verify/confirmations' => 'verify/confirmations#update'
      get '/verify/fail' => 'verify#fail'
      get '/verify/otp_delivery_method' => 'verify/otp_delivery_method#new'
      put '/verify/otp_delivery_method' => 'verify/otp_delivery_method#create'
      get '/verify/phone' => 'verify/phone#new'
      put '/verify/phone' => 'verify/phone#create'
      get '/verify/phone/result' => 'verify/phone#show'
      get '/verify/review' => 'verify/review#new'
      put '/verify/review' => 'verify/review#create'
      get '/verify/session' => 'verify/sessions#new'
      put '/verify/session' => 'verify/sessions#create'
      get '/verify/session/result' => 'verify/sessions#show'
      delete '/verify/session' => 'verify/sessions#destroy'
      get '/verify/session/dupe' => 'verify/sessions#dupe'

    end

    if FeatureManagement.enable_usps_verification?
      get '/account/verify' => 'users/verify_account#index', as: :verify_account
      post '/account/verify' => 'users/verify_account#create'
      get '/verify/usps' => 'verify/usps#index'
      put '/verify/usps' => 'verify/usps#create'
    end

    root to: 'users/sessions#new'
  end

  # Make sure any new routes are added above this line!
  # The line below will route all requests that aren't
  # defined route to the 404 page. Therefore, anything you put after this rule
  # will be ignored.
  match '*path', via: :all, to: 'pages#page_not_found'
end

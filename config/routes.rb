Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new
  mount Split::Dashboard => '/split', constraints: AdminConstraint.new

  # Devise handles login itself. It's first in the chain to avoid a redirect loop during
  # authentication failure.
  devise_for :users, skip: [:sessions, :registrations], controllers: {
    confirmations: 'users/confirmations',
    omniauth_callbacks: 'users/omniauth_callbacks',
    passwords: 'users/passwords'
  }

  # Additional device controller routes.
  devise_scope :user do
    get '/' => 'users/sessions#new', as: :new_user_session
    post '/' => 'users/sessions#create', as: :user_session
    get '/reauthn' => 'mfa_confirmation#new', as: :user_password_confirm
    post '/reauthn' => 'mfa_confirmation#create', as: :reauthn_user_password

    get '/sign_up/enter_email' => 'sign_up/registrations#new', as: :sign_up_email
    post '/sign_up/register' => 'sign_up/registrations#create', as: :sign_up_register
    get '/sign_up/start' => 'sign_up/registrations#show', as: :sign_up_start
    get '/sign_up/verify_email' => 'sign_up/emails#show', as: :sign_up_verify_email

    get 'active'  => 'users/sessions#active'
    get 'timeout' => 'users/sessions#timeout'

    patch '/confirm' => 'users/confirmations#confirm'

    get '/phone_setup' => 'devise/two_factor_authentication_setup#index'
    patch '/phone_setup' => 'devise/two_factor_authentication_setup#set'

    get '/otp/send' => 'devise/two_factor_authentication#send_code'
    get '/login/two-factor/authenticator' => 'two_factor_authentication/totp_verification#show'
    post '/login/two-factor/authenticator' => 'two_factor_authentication/totp_verification#create'
    # rubocop:disable LineLength
    get '/login/two-factor/recovery-code' => 'two_factor_authentication/recovery_code_verification#show'
    post '/login/two-factor/recovery-code' => 'two_factor_authentication/recovery_code_verification#create'
    # rubocop:enable LineLength
    get(
      '/login/two-factor/:delivery_method' => 'two_factor_authentication/otp_verification#show',
      as: :login_two_factor
    )
    post(
      '/login/two-factor/:delivery_method' => 'two_factor_authentication/otp_verification#create',
      as: :login_otp
    )
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
  get '/api/health/workers' => 'health/workers#index'
  get '/api/saml/metadata' => 'saml_idp#metadata'
  match '/api/saml/logout' => 'saml_idp#logout',
        via: [:get, :post, :delete],
        as: :destroy_user_session
  match '/api/saml/auth' => 'saml_idp#auth', via: [:get, :post]
  match '/api/voice/otp/:code' => 'voice/otp#show',
        via: [:get, :post],
        as: :voice_otp,
        defaults: { format: :xml }

  get '/contact' => 'contact#new', as: :contact
  post '/contact' => 'contact#create'

  get '/edit/email' => 'users/edit_email#edit'
  match '/edit/email' => 'users/edit_email#update', via: [:patch, :put]
  get '/edit/phone' => 'users/edit_phone#edit'
  match '/edit/phone' => 'users/edit_phone#update', via: [:patch, :put]
  get '/settings/password' => 'users/edit_password#edit'
  patch '/settings/password' => 'users/edit_password#update'
  get '/settings/recovery-code' => 'two_factor_authentication/recovery_code#show'
  post '/acknowledge_recovery_code' => 'two_factor_authentication/recovery_code#acknowledge'

  get '/idv' => 'idv#index'
  get '/idv/activated' => 'idv#activated'
  get '/idv/cancel' => 'idv#cancel'
  get '/idv/fail' => 'idv#fail'
  get '/idv/retry' => 'idv#retry'
  get '/idv/questions' => 'idv/questions#index'
  post '/idv/questions' => 'idv/questions#create'
  get '/idv/confirmations' => 'idv/confirmations#index'
  post '/idv/confirmations/continue' => 'idv/confirmations#continue'
  get '/idv/session' => 'idv/sessions#new'
  put '/idv/session' => 'idv/sessions#create'
  get '/idv/session/dupe' => 'idv/sessions#dupe'
  get '/idv/finance' => 'idv/finance#new'
  put '/idv/finance' => 'idv/finance#create'
  get '/idv/phone' => 'idv/phone#new'
  put '/idv/phone' => 'idv/phone#create'
  get '/idv/review' => 'idv/review#new'
  put '/idv/review' => 'idv/review#create'

  get '/help' => 'pages#help'
  get '/privacy' => 'pages#privacy_policy'
  get '/profile' => 'profile#index', as: :profile
  get '/profile/reactivate' => 'users/reactivate_profile#index', as: :reactivate_profile
  post '/profile/reactivate' => 'users/reactivate_profile#create'
  get '/authenticator_start' => 'users/totp_setup#start'
  get '/authenticator_setup' => 'users/totp_setup#new'
  delete '/authenticator_setup' => 'users/totp_setup#disable', as: :disable_totp
  patch '/authenticator_setup' => 'users/totp_setup#confirm'

  root to: 'users/sessions#new'

  # Make sure any new routes are added above this line!
  # The line below will route all requests that aren't
  # defined route to the 404 page. Therefore, anything you put after this rule
  # will be ignored.
  match '*path', via: :all, to: 'pages#page_not_found'
end

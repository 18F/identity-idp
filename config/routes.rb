Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
    mount Split::Dashboard => '/split'
  end

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

    post '/users' => 'users/registrations#create', as: :user_registration
    get '/users/sign_up' => 'users/registrations#new', as: :new_user_registration

    get '/start' => 'users/registrations#start', as: :new_user_start

    get 'active'  => 'users/sessions#active'
    get 'timeout' => 'users/sessions#timeout'

    patch '/confirm' => 'users/confirmations#confirm'

    get '/phone_setup' => 'devise/two_factor_authentication_setup#index'
    patch '/phone_setup' => 'devise/two_factor_authentication_setup#set'

    get '/otp/send' => 'devise/two_factor_authentication#send_code'
    get '/login/two-factor/authenticator' => 'two_factor_authentication/totp_verification#show'
    post '/login/two-factor/authenticator' => 'two_factor_authentication/totp_verification#create'
    get(
      '/login/two-factor/:delivery_method' => 'two_factor_authentication/otp_verification#show',
      as: :login_two_factor
    )
    post(
      '/login/two-factor/:delivery_method' => 'two_factor_authentication/otp_verification#create',
      as: :login_otp
    )
  end

  unless Figaro.env.domain_name.include?('superb.legit.domain.gov')
    # Testing routes, should not be available in live production
    namespace :test do
      # Assertion granting test start + return.
      get '/saml' => 'saml_test#start'
      get '/saml/decode_assertion' => 'saml_test#start'
      post '/saml/decode_assertion' => 'saml_test#decode_response'

      # Logout test start + return.
      get '/saml/logout' => 'saml_test#logout'
      post '/saml/decode_logoutresponse' => 'saml_test#decode_response'
      post '/saml/decode_slo_request' => 'saml_test#decode_slo_request'
    end
  end

  # Non-devise-controller routes. Alphabetically sorted.
  get '/api/saml/metadata' => 'saml_idp#metadata'
  match '/api/saml/logout' => 'saml_idp#logout',
        via: [:get, :post, :delete],
        as: :destroy_user_session
  match '/api/saml/auth' => 'saml_idp#auth', via: [:get, :post]

  get '/edit/email' => 'users/edit_email#edit'
  match '/edit/email' => 'users/edit_email#update', via: [:patch, :put]
  get '/edit/phone' => 'users/edit_phone#edit'
  match '/edit/phone' => 'users/edit_phone#update', via: [:patch, :put]
  get '/settings/password' => 'users/edit_password#edit'
  patch '/settings/password' => 'users/edit_password#update'

  get '/idv' => 'idv#index'
  get '/idv/cancel' => 'idv#cancel'
  get '/idv/phone_confirmation' => 'idv/phone_confirmation#show'
  get '/idv/phone_confirmation/send' => 'idv/phone_confirmation#send_code'
  put '/idv/phone_confirmation' => 'idv/phone_confirmation#confirm'
  get '/idv/questions' => 'idv/questions#index'
  post '/idv/questions' => 'idv/questions#create'
  get '/idv/confirmations' => 'idv/confirmations#index'
  get '/idv/session' => 'idv/sessions#new'
  put '/idv/session' => 'idv/sessions#create'
  get '/idv/session/dupe' => 'idv/sessions#dupe'
  get '/idv/finance' => 'idv/finance#new'
  put '/idv/finance' => 'idv/finance#create'
  get '/idv/phone' => 'idv/phone#new'
  put '/idv/phone' => 'idv/phone#create'
  get '/idv/review' => 'idv/review#new'
  put '/idv/review' => 'idv/review#create'

  get '/phone_confirmation' => 'users/phone_confirmation#show'
  get '/phone_confirmation/send' => 'users/phone_confirmation#send_code'
  put '/phone_confirmation' => 'users/phone_confirmation#confirm'
  get '/profile' => 'profile#index'
  get '/home' => 'home#index'
  get '/authenticator_start' => 'users/totp_setup#start'
  get '/authenticator_setup' => 'users/totp_setup#new'
  delete '/authenticator_setup' => 'users/totp_setup#disable', as: :disable_totp
  patch '/authenticator_setup' => 'users/totp_setup#confirm'

  root to: 'users/sessions#new'
end

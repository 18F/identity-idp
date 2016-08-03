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
    delete '/users' => 'users/registrations#destroy'

    get '/start' => 'users/registrations#start', as: :new_user_start
    get '/delete' => 'users/registrations#destroy_confirm', as: :user_destroy_confirm

    get 'active'  => 'users/sessions#active'
    get 'timeout' => 'users/sessions#timeout'

    patch '/confirm' => 'users/confirmations#confirm'

    match '/edit/email' => 'users/edit_info#email', via: [:get, :put], as: :edit_email
    match '/edit/mobile' => 'users/edit_info#mobile', via: [:get, :put], as: :edit_mobile

    get '/phone_setup' => 'devise/two_factor_authentication_setup#index'
    patch '/phone_setup' => 'devise/two_factor_authentication_setup#set'

    get '/otp/new' => 'devise/two_factor_authentication#new'
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

  # Non-devise-contoller routes. Alphabetically sorted.
  get '/api/saml/metadata' => 'saml_idp#metadata'
  match '/api/saml/logout' => 'saml_idp#logout',
        via: [:get, :post, :delete],
        as: :destroy_user_session
  match '/api/saml/auth' => 'saml_idp#auth', via: [:get, :post]
  get '/idv' => 'idv#index'
  namespace :idv do
    resources :questions, :sessions, :confirmations
  end
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

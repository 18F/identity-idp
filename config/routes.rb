require 'sidekiq/web'

Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  match '/dashboard' => 'dashboard#index', as: :dashboard_index, via: :get

  # Devise handles login itself. It's first in the chain to avoid a redirect loop during
  # authentication failure.
  devise_for :users, skip: [:sessions], controllers: {
    confirmations: 'users/confirmations',
    omniauth_callbacks: 'users/omniauth_callbacks',
    passwords: 'users/passwords',
    registrations: 'users/registrations'
  }

  devise_scope :user do
    get '/' => 'users/sessions#new', as: :new_user_session
    post '/' => 'users/sessions#create', as: :user_session

    get 'active'  => 'users/sessions#active'
    get 'timeout' => 'users/sessions#timeout'

    get '/dashboard' => 'dashboard#index', as: :user_root

    patch '/confirm' => 'users/confirmations#confirm'

    get '/users/otp' => 'devise/two_factor_authentication_setup#index'
    patch '/users/otp' => 'devise/two_factor_authentication_setup#set'
    get '/users/otp/new' => 'devise/two_factor_authentication#new'
  end

  match '/api/saml/auth' => 'saml_idp#auth', via: [:get, :post]
  get '/api/saml/metadata' => 'saml_idp#metadata'
  match '/api/saml/logout' => 'saml_idp#logout',
        via: [:get, :post, :delete],
        as: :destroy_user_session

  unless Figaro.env.domain_name.include?('superb.legit.domain.gov')
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

  root to: 'users/sessions#new'
end

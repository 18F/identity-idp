require 'sidekiq/web'

Rails.application.routes.draw do
  authenticate :user, ->(u) { u.admin? } do
    mount Sidekiq::Web => '/sidekiq'
  end

  match '/dashboard' => 'dashboard#index', as: :dashboard_index, via: :get

  get 'terms' => 'terms#index'

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
    delete 'sign_out' => 'users/sessions#destroy', as: :destroy_user_session

    get 'active'  => 'users/sessions#active'
    get 'timeout' => 'users/sessions#timeout'

    get '/dashboard' => 'dashboard#index', as: :user_root

    patch '/confirm' => 'users/confirmations#confirm'

    get '/users/otp' => 'devise/two_factor_authentication_setup#index'
    patch '/users/otp' => 'devise/two_factor_authentication_setup#set'
    get '/users/otp/new' => 'devise/two_factor_authentication#new'

    get '/users/questions' => 'devise/security_questions#new'
    get '/users/questions/confirm' => 'devise/security_questions#confirm'
    post '/users/questions/confirm' => 'devise/security_questions#check'
    match '/users/questions' => 'devise/security_questions#update', via: [:patch, :post]

    get '/users/type' => 'devise/account_type#type'
    patch '/users/type' => 'devise/account_type#set_type', as: 'set_type'
    get '/users/type/confirm' => 'devise/account_type#confirm_type'
  end

  resources :users

  get '/users/:id/reset_password' => 'users#reset_password', as: :user_reset_password

  root to: 'users/sessions#new'
end

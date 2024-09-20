Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get '/saml/auth' => 'saml_idp#new'
  post '/saml/auth' => 'saml_idp#create'

  post '/saml/consume' => 'saml#consume'
end

RailsApp::Application.routes.draw do
  get '/saml/auth' => 'saml_idp#new'
  post '/saml/auth' => 'saml_idp#create'

  post '/saml/consume' => 'saml#consume'
end

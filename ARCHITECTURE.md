## Architecture

### High-level overview
![Draft Architecture](http://anony.ws/i/2016/05/10/draft-architecture-overviewae85b.png)

The current service-level architecture is comprised of Service Providers, the Government Identity Provider, and the ability to delegate authentication to external Identity Providers. The Government IdP also handles account management. 

* The current counter fraud components are related to prevention of bad requests and activities with automated reporting.


#### Application architecture
![Draft application architecture](http://anony.ws/i/2016/06/03/draft-application-architecture.png)

### SAML Profile
[Web SSO Profile](SAML_PROFILE.md)


### Routes
```
                                    Prefix Verb            URI Pattern                                            Controller#Action
                               sidekiq_web                 /sidekiq                                               Sidekiq::Web
                           split_dashboard                 /split                                                 Split::Dashboard
                             profile_index GET             /profile(.:format)                                     profile#index
                                    splash GET             /splash(.:format)                                      home#index
              user_saml_omniauth_authorize GET|POST        /users/auth/saml(.:format)                             users/omniauth_callbacks#passthru
               user_saml_omniauth_callback GET|POST        /users/auth/saml/callback(.:format)                    users/omniauth_callbacks#saml
                             user_password POST            /users/password(.:format)                              users/passwords#create
                         new_user_password GET             /users/password/new(.:format)                          users/passwords#new
                        edit_user_password GET             /users/password/edit(.:format)                         users/passwords#edit
                                           PATCH           /users/password(.:format)                              users/passwords#update
                                           PUT             /users/password(.:format)                              users/passwords#update
                  cancel_user_registration GET             /users/cancel(.:format)                                users/registrations#cancel
                         user_registration POST            /users(.:format)                                       users/registrations#create
                     new_user_registration GET             /users/sign_up(.:format)                               users/registrations#new
                    edit_user_registration GET             /users/edit(.:format)                                  users/registrations#edit
                                           PATCH           /users(.:format)                                       users/registrations#update
                                           PUT             /users(.:format)                                       users/registrations#update
                                           DELETE          /users(.:format)                                       users/registrations#destroy
                         user_confirmation POST            /users/confirmation(.:format)                          users/confirmations#create
                     new_user_confirmation GET             /users/confirmation/new(.:format)                      users/confirmations#new
                                           GET             /users/confirmation(.:format)                          users/confirmations#show
resend_code_user_two_factor_authentication GET             /users/two_factor_authentication/resend_code(.:format) devise/two_factor_authentication#resend_code
            user_two_factor_authentication GET             /users/two_factor_authentication(.:format)             devise/two_factor_authentication#show
                                           PATCH           /users/two_factor_authentication(.:format)             devise/two_factor_authentication#update
                                           PUT             /users/two_factor_authentication(.:format)             devise/two_factor_authentication#update
                          new_user_session GET             /                                                      users/sessions#new
                              user_session POST            /                                                      users/sessions#create
                            new_user_start GET             /start(.:format)                                       users/registrations#start
                      user_destroy_confirm GET             /delete(.:format)                                      users/registrations#destroy_confirm
                                    active GET             /active(.:format)                                      users/sessions#active
                                   timeout GET             /timeout(.:format)                                     users/sessions#timeout
                                 user_root GET             /profile(.:format)                                     profile#index
                                   confirm PATCH           /confirm(.:format)                                     users/confirmations#confirm
                                users_totp GET             /users/totp(.:format)                                  users/totp_setup#new
                              disable_totp DELETE          /users/totp(.:format)                                  users/totp_setup#disable
                              confirm_totp PATCH           /users/totp(.:format)                                  users/totp_setup#confirm
                        phone_confirmation GET             /phone_confirmation(.:format)                          users/phone_confirmation#show
                   phone_confirmation_send GET             /phone_confirmation/send(.:format)                     users/phone_confirmation#send_code
                                           PUT             /phone_confirmation(.:format)                          users/phone_confirmation#confirm
                                 users_otp GET             /users/otp(.:format)                                   devise/two_factor_authentication_setup#index
                                           PATCH           /users/otp(.:format)                                   devise/two_factor_authentication_setup#set
                             users_otp_new GET             /users/otp/new(.:format)                               devise/two_factor_authentication#new
                             api_saml_auth GET|POST        /api/saml/auth(.:format)                               saml_idp#auth
                         api_saml_metadata GET             /api/saml/metadata(.:format)                           saml_idp#metadata
                      destroy_user_session GET|POST|DELETE /api/saml/logout(.:format)                             saml_idp#logout
                                 test_saml GET             /test/saml(.:format)                                   test/saml_test#start
                test_saml_decode_assertion GET             /test/saml/decode_assertion(.:format)                  test/saml_test#start
                                           POST            /test/saml/decode_assertion(.:format)                  test/saml_test#decode_response
                          test_saml_logout GET             /test/saml/logout(.:format)                            test/saml_test#logout
           test_saml_decode_logoutresponse POST            /test/saml/decode_logoutresponse(.:format)             test/saml_test#decode_response
              test_saml_decode_slo_request POST            /test/saml/decode_slo_request(.:format)                test/saml_test#decode_slo_request
                                       idv GET             /idv(.:format)                                         idv#index
                             idv_questions GET             /idv/questions(.:format)                               idv/questions#index
                                           POST            /idv/questions(.:format)                               idv/questions#create
                          new_idv_question GET             /idv/questions/new(.:format)                           idv/questions#new
                         edit_idv_question GET             /idv/questions/:id/edit(.:format)                      idv/questions#edit
                              idv_question GET             /idv/questions/:id(.:format)                           idv/questions#show
                                           PATCH           /idv/questions/:id(.:format)                           idv/questions#update
                                           PUT             /idv/questions/:id(.:format)                           idv/questions#update
                                           DELETE          /idv/questions/:id(.:format)                           idv/questions#destroy
                              idv_sessions GET             /idv/sessions(.:format)                                idv/sessions#index
                                           POST            /idv/sessions(.:format)                                idv/sessions#create
                           new_idv_session GET             /idv/sessions/new(.:format)                            idv/sessions#new
                          edit_idv_session GET             /idv/sessions/:id/edit(.:format)                       idv/sessions#edit
                               idv_session GET             /idv/sessions/:id(.:format)                            idv/sessions#show
                                           PATCH           /idv/sessions/:id(.:format)                            idv/sessions#update
                                           PUT             /idv/sessions/:id(.:format)                            idv/sessions#update
                                           DELETE          /idv/sessions/:id(.:format)                            idv/sessions#destroy
                         idv_confirmations GET             /idv/confirmations(.:format)                           idv/confirmations#index
                                           POST            /idv/confirmations(.:format)                           idv/confirmations#create
                      new_idv_confirmation GET             /idv/confirmations/new(.:format)                       idv/confirmations#new
                     edit_idv_confirmation GET             /idv/confirmations/:id/edit(.:format)                  idv/confirmations#edit
                          idv_confirmation GET             /idv/confirmations/:id(.:format)                       idv/confirmations#show
                                           PATCH           /idv/confirmations/:id(.:format)                       idv/confirmations#update
                                           PUT             /idv/confirmations/:id(.:format)                       idv/confirmations#update
                                           DELETE          /idv/confirmations/:id(.:format)                       idv/confirmations#destroy
                                      root GET             /                                                      users/sessions#new
                               ahoy_engine                 /ahoy                                                  Ahoy::Engine

Routes for Ahoy::Engine:
visits POST /visits(.:format) ahoy/visits#create
events POST /events(.:format) ahoy/events#create
```

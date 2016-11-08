## Architecture

### High-level overview
![Draft Architecture](https://github.com/18F/identity-idp/raw/amos/feature/arch_docs_r1/docs/diagrams/draft-architecture-overview.png)

The current service-level architecture is comprised of Service Providers, the Government Identity Provider (login.gov), and the ability to verify identity within login.gov using various back-end systems (credit authorities, document verifications services, etc.) or delegate authentication to external Identity Providers.

* The current counter fraud components are related to prevention of bad requests and activities with automated reporting.

For more details on our system security, see [SECURITY.md](SECURITY.md).


#### Application architecture
![Draft application architecture](https://github.com/18F/identity-idp/raw/amos/feature/arch_docs_r1/docs/diagrams/draft-application-architecture.png)


#### Entity-relationship Diagram
![ERD](https://github.com/18F/identity-idp/raw/amos/feature/arch_docs_r1/docs/diagrams/erd.png)


### SAML Profile
[Web SSO Profile](SAML_PROFILE.md)


### Routes
```
                                    Prefix Verb            URI Pattern                                            Controller#Action
                               sidekiq_web                 /sidekiq                                               Sidekiq::Web
                           split_dashboard                 /split                                                 Split::Dashboard
              user_saml_omniauth_authorize GET|POST        /users/auth/saml(.:format)                             users/omniauth_callbacks#passthru
               user_saml_omniauth_callback GET|POST        /users/auth/saml/callback(.:format)                    users/omniauth_callbacks#saml
                             user_password POST            /users/password(.:format)                              users/passwords#create
                         new_user_password GET             /users/password/new(.:format)                          users/passwords#new
                        edit_user_password GET             /users/password/edit(.:format)                         users/passwords#edit
                                           PATCH           /users/password(.:format)                              users/passwords#update
                                           PUT             /users/password(.:format)                              users/passwords#update
                         user_confirmation POST            /users/confirmation(.:format)                          users/confirmations#create
                     new_user_confirmation GET             /users/confirmation/new(.:format)                      users/confirmations#new
                                           GET             /users/confirmation(.:format)                          users/confirmations#show
resend_code_user_two_factor_authentication GET             /users/two_factor_authentication/resend_code(.:format) devise/two_factor_authentication#resend_code
            user_two_factor_authentication GET             /users/two_factor_authentication(.:format)             devise/two_factor_authentication#show
                                           PATCH           /users/two_factor_authentication(.:format)             devise/two_factor_authentication#update
                                           PUT             /users/two_factor_authentication(.:format)             devise/two_factor_authentication#update
                          new_user_session GET             /                                                      users/sessions#new
                              user_session POST            /                                                      users/sessions#create
                     user_password_confirm GET             /reauthn(.:format)                                     mfa_confirmation#new
                     reauthn_user_password POST            /reauthn(.:format)                                     mfa_confirmation#create
                         user_registration POST            /users(.:format)                                       users/registrations#create
                     new_user_registration GET             /users/sign_up(.:format)                               users/registrations#new
                            new_user_start GET             /start(.:format)                                       users/registrations#start
                                    active GET             /active(.:format)                                      users/sessions#active
                                   timeout GET             /timeout(.:format)                                     users/sessions#timeout
                                   confirm PATCH           /confirm(.:format)                                     users/confirmations#confirm
                               phone_setup GET             /phone_setup(.:format)                                 devise/two_factor_authentication_setup#index
                                           PATCH           /phone_setup(.:format)                                 devise/two_factor_authentication_setup#set
                                  otp_send GET             /otp/send(.:format)                                    devise/two_factor_authentication#send_code
            login_two_factor_authenticator GET             /login/two-factor/authenticator(.:format)              two_factor_authentication/totp_verification#show
                                           POST            /login/two-factor/authenticator(.:format)              two_factor_authentication/totp_verification#create
            login_two_factor_recovery_code GET             /login/two-factor/recovery-code(.:format)              two_factor_authentication/recovery_code_verification#show
                                           POST            /login/two-factor/recovery-code(.:format)              two_factor_authentication/recovery_code_verification#create
                          login_two_factor GET             /login/two-factor/:delivery_method(.:format)           two_factor_authentication/otp_verification#show
                                 login_otp POST            /login/two-factor/:delivery_method(.:format)           two_factor_authentication/otp_verification#create
                         api_saml_metadata GET             /api/saml/metadata(.:format)                           saml_idp#metadata
                      destroy_user_session GET|POST|DELETE /api/saml/logout(.:format)                             saml_idp#logout
                             api_saml_auth GET|POST        /api/saml/auth(.:format)                               saml_idp#auth
                                   contact GET             /contact(.:format)                                     contact#new
                                           POST            /contact(.:format)                                     contact#create
                                edit_email GET             /edit/email(.:format)                                  users/edit_email#edit
                                           PATCH|PUT       /edit/email(.:format)                                  users/edit_email#update
                                edit_phone GET             /edit/phone(.:format)                                  users/edit_phone#edit
                                           PATCH|PUT       /edit/phone(.:format)                                  users/edit_phone#update
                         settings_password GET             /settings/password(.:format)                           users/edit_password#edit
                                           PATCH           /settings/password(.:format)                           users/edit_password#update
                    settings_recovery_code GET             /settings/recovery-code(.:format)                      two_factor_authentication/recovery_code#show
                 acknowledge_recovery_code POST            /acknowledge_recovery_code(.:format)                   two_factor_authentication/recovery_code#acknowledge
                                       idv GET             /idv(.:format)                                         idv#index
                             idv_activated GET             /idv/activated(.:format)                               idv#activated
                                idv_cancel GET             /idv/cancel(.:format)                                  idv#cancel
                                  idv_fail GET             /idv/fail(.:format)                                    idv#fail
                                 idv_retry GET             /idv/retry(.:format)                                   idv#retry
                             idv_questions GET             /idv/questions(.:format)                               idv/questions#index
                                           POST            /idv/questions(.:format)                               idv/questions#create
                         idv_confirmations GET             /idv/confirmations(.:format)                           idv/confirmations#index
                               idv_session GET             /idv/session(.:format)                                 idv/sessions#new
                                           PUT             /idv/session(.:format)                                 idv/sessions#create
                          idv_session_dupe GET             /idv/session/dupe(.:format)                            idv/sessions#dupe
                               idv_finance GET             /idv/finance(.:format)                                 idv/finance#new
                                           PUT             /idv/finance(.:format)                                 idv/finance#create
                                 idv_phone GET             /idv/phone(.:format)                                   idv/phone#new
                                           PUT             /idv/phone(.:format)                                   idv/phone#create
                                idv_review GET             /idv/review(.:format)                                  idv/review#new
                                           PUT             /idv/review(.:format)                                  idv/review#create
                                   privacy GET             /privacy(.:format)                                     pages#privacy_policy
                                   profile GET             /profile(.:format)                                     profile#index
                       authenticator_start GET             /authenticator_start(.:format)                         users/totp_setup#start
                       authenticator_setup GET             /authenticator_setup(.:format)                         users/totp_setup#new
                              disable_totp DELETE          /authenticator_setup(.:format)                         users/totp_setup#disable
                                           PATCH           /authenticator_setup(.:format)                         users/totp_setup#confirm
                                      root GET             /                                                      users/sessions#new
                                                           /*path(.:format)                                       pages#page_not_found
```

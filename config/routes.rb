Rails.application.routes.draw do
  # Non i18n routes. Alphabetically sorted.
  get '/api/analytics-events' => 'analytics_events#index'
  get '/api/country-support' => 'country_support#index'
  get '/api/health' => 'health/health#index'
  get '/api/health/database' => 'health/database#index'
  get '/api/health/jobs' => 'health/health#index'
  get '/api/health/outbound' => 'health/outbound#index'
  get '/api/openid_connect/certs' => 'openid_connect/certs#index'
  post '/api/openid_connect/token' => 'openid_connect/token#create'
  match '/api/openid_connect/token' => 'openid_connect/token#options', via: :options
  get '/api/openid_connect/userinfo' => 'openid_connect/user_info#show'
  post '/api/risc/security_events' => 'risc/security_events#create'

  post '/api/usps_locations' => 'idv/in_person/public/usps_locations#index'
  match '/api/usps_locations' => 'idv/in_person/public/usps_locations#options', via: :options

  namespace :api do
    namespace :internal do
      get '/sessions' => 'sessions#show'
      put '/sessions' => 'sessions#update'

      namespace :two_factor_authentication do
        put '/piv_cac/:id' => 'piv_cac#update', as: :piv_cac
        delete '/piv_cac/:id' => 'piv_cac#destroy', as: nil
        put '/webauthn/:id' => 'webauthn#update', as: :webauthn
        delete '/webauthn/:id' => 'webauthn#destroy', as: nil
        put '/auth_app/:id' => 'auth_app#update', as: :auth_app
        delete '/auth_app/:id' => 'auth_app#destroy', as: nil
      end
    end
  end

  # SAML secret rotation paths
  constraints(path_year: SamlEndpoint.suffixes) do
    get '/api/saml/metadata(:path_year)' => 'saml_idp#metadata', format: false
    match '/api/saml/logout(:path_year)' => 'saml_idp#logout', via: %i[get post delete],
          as: :api_saml_logout
    match '/api/saml/remotelogout(:path_year)' => 'saml_idp#remotelogout', via: %i[get post],
          as: :api_saml_remotelogout
    # JS-driven POST redirect route to preserve existing session
    post '/api/saml/auth(:path_year)' => 'saml_post#auth', as: :api_saml_auth
    # actual SAML handling POST route
    post '/api/saml/authpost(:path_year)' => 'saml_idp#auth', as: :api_saml_authpost
    # The internal auth post which will not be logged as an external request
    post '/api/saml/finalauthpost(:path_year)' => 'saml_idp#auth', as: :api_saml_finalauthpost
    get '/api/saml/auth(:path_year)' => 'saml_idp#auth'
  end
  get '/api/saml/complete' => 'saml_completion#index', as: :complete_saml

  post '/api/service_provider' => 'service_provider#update'
  post '/api/verify/images' => 'idv/image_uploads#create'
  post '/api/logger' => 'frontend_log#create'

  get '/openid_connect/authorize' => 'openid_connect/authorization#index'
  get '/openid_connect/logout' => 'openid_connect/logout#index'
  delete '/openid_connect/logout' => 'openid_connect/logout#delete'

  get '/no_js/detect.css' => 'no_js#index', as: :no_js_detect_css

  # i18n routes. Alphabetically sorted.
  scope '(:locale)', locale: /#{I18n.available_locales.join('|')}/ do
    # Devise handles login itself. It's first in the chain to avoid a redirect loop during
    # authentication failure.
    # devise_for(
    #   :users,
    #   skip: %i[confirmations sessions registrations two_factor_authentication],
    #   controllers: { passwords: 'users/reset_passwords' },
    # )

    # Additional device controller routes.
    devise_for(
      :users,
      skip: %i[confirmations sessions registrations two_factor_authentication passwords],
    )

    devise_scope :user do
      get '/users/password/new' => 'users/reset_passwords#new', as: :new_user_password
      get '/users/password/edit' => 'users/reset_passwords#edit', as: :edit_user_password
      patch '/users/password' => 'users/reset_passwords#update', as: :user_password
      put '/users/password' => 'users/reset_passwords#update', as: nil
      post '/users/password' => 'users/reset_passwords#create', as: nil

      get '/account/forget_all_browsers' => 'users/forget_all_browsers#show',
          as: :forget_all_browsers
      delete '/account/forget_all_browsers' => 'users/forget_all_browsers#destroy'

      get '/account/service_providers/:sp_id/revoke' => 'users/service_provider_revoke#show',
          as: :service_provider_revoke
      delete '/account/service_providers/:sp_id/revoke' => 'users/service_provider_revoke#destroy'

      get '/' => 'users/sessions#new', as: :new_user_session
      get '/bounced' => 'users/sp_handoff_bounced#bounced'
      post '/' => 'users/sessions#create', as: :user_session
      get '/logout' => 'users/sessions#destroy', as: :destroy_user_session
      delete '/logout' => 'users/sessions#destroy'

      get '/login/piv_cac' => 'users/piv_cac_login#new'
      get '/login/piv_cac_error' => 'users/piv_cac_login#error'

      get '/login/present_piv_cac' => 'users/piv_cac_login#redirect_to_piv_cac_service'
      get '/login/password' => 'password_capture#new', as: :capture_password
      post '/login/password' => 'password_capture#create'

      get '/account_reset/recovery_options' => 'account_reset/recovery_options#show'
      post '/account_reset/recovery_options/cancel' => 'account_reset/recovery_options#cancel'
      get '/account_reset/request' => 'account_reset/request#show'
      post '/account_reset/request' => 'account_reset/request#create'
      get '/account_reset/cancel' => 'account_reset/cancel#show'
      post '/account_reset/cancel' => 'account_reset/cancel#create'
      get '/account_reset/confirm_request' => 'account_reset/confirm_request#show'
      get '/account_reset/delete_account' => 'account_reset/delete_account#show'
      delete '/account_reset/delete_account' => 'account_reset/delete_account#delete'
      get '/account_reset/confirm_delete_account' => 'account_reset/confirm_delete_account#show'
      get '/account_reset/pending' => 'account_reset/pending#show'
      get '/account_reset/pending/confirm' => 'account_reset/pending#confirm'
      post '/account_reset/pending/cancel' => 'account_reset/pending#cancel'

      get '/login/two_factor/options' => 'two_factor_authentication/options#index'
      post '/login/two_factor/options' => 'two_factor_authentication/options#create'

      get '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#show'
      post '/login/two_factor/authenticator' => 'two_factor_authentication/totp_verification#create'
      get '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#show'
      post '/login/two_factor/personal_key' => 'two_factor_authentication/personal_key_verification#create'
      get '/login/two_factor/piv_cac' => 'two_factor_authentication/piv_cac_verification#show'
      get '/login/two_factor/piv_cac/present_piv_cac' => 'two_factor_authentication/piv_cac_verification#redirect_to_piv_cac_service'
      get '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#show'
      patch '/login/two_factor/webauthn' => 'two_factor_authentication/webauthn_verification#confirm'
      get 'login/two_factor/backup_code' => 'two_factor_authentication/backup_code_verification#show'
      post 'login/two_factor/backup_code' => 'two_factor_authentication/backup_code_verification#create'
      get  '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#show',
           as: :login_two_factor, constraints: { otp_delivery_preference: /sms|voice/ }
      post '/login/two_factor/:otp_delivery_preference' => 'two_factor_authentication/otp_verification#create',
           as: :login_otp, constraints: { otp_delivery_preference: /sms|voice/ }
      get '/login/two_factor/sms/:opt_out_uuid/opt_in' => 'two_factor_authentication/sms_opt_in#new',
          as: :login_two_factor_sms_opt_in
      post '/login/two_factor/sms/:opt_out_uuid/opt_in' => 'two_factor_authentication/sms_opt_in#create'

      get 'login/add_piv_cac/prompt' => 'users/piv_cac_setup_from_sign_in#prompt'
      post 'login/add_piv_cac/prompt' => 'users/piv_cac_setup_from_sign_in#decline'
      get 'login/add_piv_cac/success' => 'users/piv_cac_setup_from_sign_in#success'
      post 'login/add_piv_cac/success' => 'users/piv_cac_setup_from_sign_in#next'
    end

    if IdentityConfig.store.enable_test_routes
      namespace :test do
        # Assertion granting test start + return.
        get '/saml/login' => 'saml_test#index'
        get '/saml' => 'saml_test#start'
        get '/saml/decode_assertion' => 'saml_test#start'
        post '/saml/decode_assertion' => 'saml_test#decode_response'
        post '/saml/decode_slo_request' => 'saml_test#decode_slo_request'

        get '/oidc/login' => 'oidc_test#index'
        get '/oidc' => 'oidc_test#start'
        get '/oidc/auth_request' => 'oidc_test#auth_request'
        get '/oidc/auth_result' => 'oidc_test#auth_result'
        get '/oidc/logout' => 'oidc_test#logout'

        get '/piv_cac_entry' => 'piv_cac_authentication_test_subject#new'
        post '/piv_cac_entry' => 'piv_cac_authentication_test_subject#create'

        get '/telephony' => 'telephony#index'
        delete '/telephony' => 'telephony#destroy'
        get '/push_notification' => 'push_notification#index'
        delete '/push_notification' => 'push_notification#destroy'

        get '/s3/:key' => 'fake_s3#show', as: :fake_s3
        put '/s3/:key' => 'fake_s3#update'

        get '/session_data' => 'session_data#index'
      end
    end

    if IdentityConfig.store.component_previews_enabled
      require 'lookbook'
      mount Lookbook::Engine, at: '/components'
    end

    if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
      get '/test/device_profiling' => 'test/device_profiling#index',
          as: :test_device_profiling_iframe
      post '/test/device_profiling' => 'test/device_profiling#create'
    end

    get '/auth_method_confirmation' => 'mfa_confirmation#show'
    post '/auth_method_confirmation/skip' => 'mfa_confirmation#skip'

    # Non-devise-controller routes. Alphabetically sorted.
    get '/.well-known/openid-configuration' => 'openid_connect/configuration#index',
        as: :openid_connect_configuration
    get '/.well-known/risc-configuration' => 'risc/configuration#index',
        as: :risc_configuration

    get '/account' => 'accounts#show'
    get '/account/connected_accounts' => 'accounts/connected_accounts#show'
    post '/account/reauthentication' => 'accounts#reauthentication'
    get '/account/devices/:id/events' => 'events#show', as: :account_events
    get '/account/delete' => 'users/delete#show', as: :account_delete
    post '/account/delete' => 'users/delete#delete'
    get '/account/email_language' => 'users/email_language#show', as: :account_email_language
    patch '/account/email_language' => 'users/email_language#update'
    get '/account/history' => 'accounts/history#show'
    get '/account/reactivate/start' => 'reactivate_account#index', as: :reactivate_account
    put '/account/reactivate/start' => 'reactivate_account#update'
    get '/account/reactivate/verify_password' => 'users/verify_password#new', as: :verify_password
    put '/account/reactivate/verify_password' => 'users/verify_password#update',
        as: :update_verify_password
    get '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#new',
        as: :verify_personal_key
    post '/account/reactivate/verify_personal_key' => 'users/verify_personal_key#create',
         as: :create_verify_personal_key
    get '/account/two_factor_authentication' => 'accounts/two_factor_authentication#show'

    get '/errors/service_provider_inactive' => 'users/service_provider_inactive#index',
        as: :sp_inactive_error
    get '/errors/vendor' => 'vendor_outage#show', as: :vendor_outage

    get '/events/disavow' => 'event_disavowal#new', as: :event_disavowal
    post '/events/disavow' => 'event_disavowal#create', as: :events_disavowal

    get '/rules_of_use' => 'users/rules_of_use#new'
    post '/rules_of_use' => 'users/rules_of_use#create'

    get '/second_mfa_reminder' => 'users/second_mfa_reminder#new'
    post '/second_mfa_reminder' => 'users/second_mfa_reminder#create'

    get '/piv_cac' => 'users/piv_cac_authentication_setup#new', as: :setup_piv_cac
    get '/piv_cac_error' => 'users/piv_cac_authentication_setup#error', as: :setup_piv_cac_error
    post '/present_piv_cac' => 'users/piv_cac_authentication_setup#submit_new_piv_cac',
         as: :submit_new_piv_cac

    get '/webauthn_setup' => 'users/webauthn_setup#new', as: :webauthn_setup
    patch '/webauthn_setup' => 'users/webauthn_setup#confirm'

    get '/authenticator_setup' => 'users/totp_setup#new'
    patch '/authenticator_setup' => 'users/totp_setup#confirm'

    get '/forgot_password' => 'forgot_password#show'

    get '/manage/password' => 'users/passwords#edit'
    patch '/manage/password' => 'users/passwords#update'

    get '/add/email' => 'users/emails#show'
    post '/add/email' => 'users/emails#add'
    get '/add/email/confirm' => 'users/email_confirmations#create', as: :add_email_confirmation
    get '/add/email/verify_email' => 'users/emails#verify', as: :add_email_verify_email
    post '/add/email/resend' => 'users/emails#resend'

    delete '/manage/email/:id' => 'users/emails#delete', as: :delete_email
    get '/manage/email/confirm_delete/:id' => 'users/emails#confirm_delete',
        as: :manage_email_confirm_delete

    get '/manage/phone/:id' => 'users/edit_phone#edit', as: :manage_phone
    match '/manage/phone/:id' => 'users/edit_phone#update', via: %i[patch put]
    delete '/manage/phone/:id' => 'users/edit_phone#destroy'
    get '/manage/personal_key' => 'users/personal_keys#show', as: :manage_personal_key
    post '/manage/personal_key' => 'users/personal_keys#update'
    get '/manage/piv_cac/:id' => 'users/piv_cac#edit', as: :edit_piv_cac
    put '/manage/piv_cac/:id' => 'users/piv_cac#update', as: :piv_cac
    delete '/manage/piv_cac/:id' => 'users/piv_cac#destroy', as: nil
    get '/manage/webauthn/:id' => 'users/webauthn#edit', as: :edit_webauthn
    put '/manage/webauthn/:id' => 'users/webauthn#update', as: :webauthn
    delete '/manage/webauthn/:id' => 'users/webauthn#destroy', as: nil
    get '/manage/auth_app/:id' => 'users/auth_app#edit', as: :edit_auth_app
    put '/manage/auth_app/:id' => 'users/auth_app#update', as: :auth_app
    delete '/manage/auth_app/:id' => 'users/auth_app#destroy', as: nil
    get '/account/personal_key' => 'accounts/personal_keys#new', as: :create_new_personal_key
    post '/account/personal_key' => 'accounts/personal_keys#create'

    get '/otp/send' => 'users/two_factor_authentication#send_code'

    get '/authentication_methods_setup' => 'users/two_factor_authentication_setup#index'
    patch '/authentication_methods_setup' => 'users/two_factor_authentication_setup#create'
    get '/phone_setup' => 'users/phone_setup#index'
    post '/phone_setup' => 'users/phone_setup#create'
    get '/users/two_factor_authentication' => 'users/two_factor_authentication#show',
        as: :user_two_factor_authentication # route name is used by two_factor_authentication gem
    get '/backup_code_refreshed' => 'users/backup_code_setup#refreshed'
    get '/backup_code_reminder' => 'users/backup_code_setup#reminder'
    get '/backup_code_setup' => 'users/backup_code_setup#index'
    patch '/backup_code_setup' => 'users/backup_code_setup#create', as: :backup_code_create
    patch '/backup_code_continue' => 'users/backup_code_setup#continue'
    get '/backup_code_regenerate' => 'users/backup_code_setup#edit'
    get '/backup_code_delete' => 'users/backup_code_setup#confirm_delete'
    delete '/backup_code_delete' => 'users/backup_code_setup#delete'
    get '/confirm_backup_codes' => 'users/backup_code_setup#confirm_backup_codes'

    get '/user_please_call' => 'users/please_call#show'

    post '/sign_up/create_password' => 'sign_up/passwords#create', as: :sign_up_create_password
    get '/sign_up/email/confirm' => 'sign_up/email_confirmations#create',
        as: :sign_up_create_email_confirmation
    get '/sign_up/enter_email' => 'sign_up/registrations#new', as: :sign_up_email
    post '/sign_up/enter_email' => 'sign_up/registrations#create', as: :sign_up_register
    get '/sign_up/enter_email/resend' => 'sign_up/email_resend#new', as: :sign_up_email_resend
    get '/sign_up/enter_password' => 'sign_up/passwords#new'
    get '/sign_up/verify_email' => 'sign_up/emails#show', as: :sign_up_verify_email
    get '/sign_up/completed' => 'sign_up/completions#show', as: :sign_up_completed
    post '/sign_up/completed' => 'sign_up/completions#update'
    get '/user_authorization_confirmation' => 'users/authorization_confirmation#new'
    post '/user_authorization_confirmation' => 'users/authorization_confirmation#create'
    match '/user_authorization_confirmation/reset' => 'users/authorization_confirmation#destroy',
          as: :reset_user_authorization, via: %i[put delete]
    get '/sign_up/cancel/' => 'sign_up/cancellations#new', as: :sign_up_cancel
    delete '/sign_up/cancel' => 'sign_up/cancellations#destroy', as: :sign_up_destroy

    get '/redirect/return_to_sp/cancel' => 'redirect/return_to_sp#cancel', as: :return_to_sp_cancel
    get '/redirect/return_to_sp/failure_to_proof' => 'redirect/return_to_sp#failure_to_proof',
        as: :return_to_sp_failure_to_proof
    get '/redirect/help_center' => 'redirect/help_center#show', as: :help_center_redirect
    get '/redirect/contact/' => 'redirect/contact#show', as: :contact_redirect
    get '/redirect/policy/' => 'redirect/policy#show', as: :policy_redirect

    match '/sign_out' => 'sign_out#destroy', via: %i[get post delete]

    get '/restricted' => 'banned_user#show', as: :banned_user

    get '/errors/idv_unavailable' => 'idv/unavailable#show', as: :idv_unavailable

    scope '/verify', as: 'idv' do
      get '/' => 'idv#index'
      get '/activated' => 'idv#activated'
    end
    scope '/verify', module: 'idv', as: 'idv' do
      get '/mail_only_warning' => 'mail_only_warning#show'
      get '/personal_key' => 'personal_key#show'
      post '/personal_key' => 'personal_key#update'
      get '/forgot_password' => 'forgot_password#new'
      post '/forgot_password' => 'forgot_password#update'
      get '/agreement' => 'agreement#show'
      put '/agreement' => 'agreement#update'
      get '/how_to_verify' => 'how_to_verify#show'
      put '/how_to_verify' => 'how_to_verify#update'
      get '/document_capture' => 'document_capture#show'
      put '/document_capture' => 'document_capture#update'
      # This route is included in SMS messages sent to users who start the IdV hybrid flow. It
      # should be kept short, and should not include underscores ("_").
      get '/documents' => 'hybrid_mobile/entry#show', as: :hybrid_mobile_entry
      get '/hybrid_mobile/document_capture' => 'hybrid_mobile/document_capture#show'
      put '/hybrid_mobile/document_capture' => 'hybrid_mobile/document_capture#update'
      get '/hybrid_mobile/capture_complete' => 'hybrid_mobile/capture_complete#show'
      get '/hybrid_handoff' => 'hybrid_handoff#show'
      put '/hybrid_handoff' => 'hybrid_handoff#update'
      get '/link_sent' => 'link_sent#show'
      put '/link_sent' => 'link_sent#update'
      get '/link_sent/poll' => 'capture_doc_status#show', as: :capture_doc_status
      get '/ssn' => 'ssn#show'
      put '/ssn' => 'ssn#update'
      get '/verify_info' => 'verify_info#show'
      put '/verify_info' => 'verify_info#update'
      get '/welcome' => 'welcome#show'
      put '/welcome' => 'welcome#update'
      get '/phone' => 'phone#new'
      put '/phone' => 'phone#create'
      get '/phone/errors/warning' => 'phone_errors#warning'
      get '/phone/errors/jobfail' => 'phone_errors#jobfail'
      get '/phone/errors/failure' => 'phone_errors#failure'
      post '/phone/resend_code' => 'resend_otp#create', as: :resend_otp
      get '/phone_confirmation' => 'otp_verification#show', as: :otp_verification
      put '/phone_confirmation' => 'otp_verification#update', as: :nil
      get '/enter_password' => 'enter_password#new'
      put '/enter_password' => 'enter_password#create'
      get '/session/errors/warning' => 'session_errors#warning'
      get '/session/errors/state_id_warning' => 'session_errors#state_id_warning'
      get '/phone/errors/timeout' => 'phone_errors#timeout'
      get '/session/errors/failure' => 'session_errors#failure'
      get '/session/errors/ssn_failure' => 'session_errors#ssn_failure'
      get '/session/errors/exception' => 'session_errors#exception'
      get '/session/errors/rate_limited' => 'session_errors#rate_limited'
      get '/not_verified' => 'not_verified#show'
      get '/please_call' => 'please_call#show'
      delete '/session' => 'sessions#destroy'
      get '/cancel/' => 'cancellations#new', as: :cancel
      put '/cancel' => 'cancellations#update'
      delete '/cancel' => 'cancellations#destroy'
      get '/exit' => 'cancellations#exit', as: :exit
      get '/address' => 'address#new'
      post '/address' => 'address#update'
      get '/capture_doc' => 'hybrid_mobile/entry#show'
      get '/capture-doc' => 'hybrid_mobile/entry#show',
          # sometimes underscores get messed up when linked to via SMS
          as: :capture_doc_dashes

      get '/in_person_proofing/address' => 'in_person/address#show'
      put '/in_person_proofing/address' => 'in_person/address#update'

      get '/in_person' => 'in_person#index'
      get '/in_person/ready_to_verify' => 'in_person/ready_to_verify#show',
          as: :in_person_ready_to_verify
      post '/in_person/usps_locations' => 'in_person/usps_locations#index'
      put '/in_person/usps_locations' => 'in_person/usps_locations#update'
      get '/in_person/ssn' => 'in_person/ssn#show'
      put '/in_person/ssn' => 'in_person/ssn#update'
      get '/in_person/verify_info' => 'in_person/verify_info#show'
      put '/in_person/verify_info' => 'in_person/verify_info#update'
      get '/in_person/:step' => 'in_person#show', as: :in_person_step
      put '/in_person/:step' => 'in_person#update'

      get '/by_mail/enter_code' => 'by_mail/enter_code#index', as: :verify_by_mail_enter_code
      post '/by_mail/enter_code' => 'by_mail/enter_code#create'
      get '/by_mail/enter_code/rate_limited' => 'by_mail/enter_code_rate_limited#index',
          as: :enter_code_rate_limited
      get '/by_mail/confirm_start_over' => 'confirm_start_over#index',
          as: :confirm_start_over
      get '/by_mail/confirm_start_over/before_letter' => 'confirm_start_over#before_letter',
          as: :confirm_start_over_before_letter

      if FeatureManagement.gpo_verification_enabled?
        get '/by_mail/request_letter' => 'by_mail/request_letter#index', as: :request_letter
        put '/by_mail/request_letter' => 'by_mail/request_letter#create'

        # Temporary routes + redirects supporting GPO route renaming
        get '/usps' => redirect('/verify/by_mail/request_letter')
        put '/usps' => 'by_mail/request_letter#create'
      end

      get '/by_mail/letter_enqueued' => 'by_mail/letter_enqueued#show', as: :letter_enqueued

      # We re-mapped `/verify/by_mail` to `/verify/by_mail/enter_code`. However, we sent emails to
      # users with a link to `/verify/by_mail?did_not_receive_letter=1`. We need to continue
      # supporting that feature so we are maintaining this URL mapped to that action. Rendering a
      # redirect here will strip the query parameter.
      get '/by_mail' => 'by_mail/enter_code#index'
    end

    root to: 'users/sessions#new'
  end

  # Make sure any new routes are added above this line!
  # The line below will route all requests that aren't
  # defined route to the 404 page. Therefore, anything you put after this rule
  # will be ignored.
  match '*path', via: :all, to: 'pages#page_not_found'
end

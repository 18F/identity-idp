# frozen_string_literal: true

# This is only used in development/test. Routes aren't constructed unless
# IdentityConfig.store.enable_test_routes is true, and the controller renders
# 404 otherwise as defense in depth. It renders the real NDS auth views with
# fabricated presenters/ivars so a developer can inspect every page state
# without walking the whole flow.
module Test
  class NDSPagesController < ApplicationController
    SpSessionStub = Struct.new(:sp_name, :sp_alert_text, :cancel_link_url, keyword_init: true) do
      def sp_alert(_section)
        sp_alert_text
      end

      def remember_device_default
        true
      end
    end

    ServiceProviderStub = Struct.new(:logo, :logo_url, :issuer, keyword_init: true)

    EmailAddressStub = Struct.new(:email, keyword_init: true)

    DEV_USER_EMAIL = 'nds-explorer-dev@example.com'
    DEV_DUPLICATE_EMAIL = 'nds-explorer-dupe@example.com'
    DEV_USER_PASSWORD = 'NDS explorer dev pass!1'
    DEV_PHONE = '+12025551212'
    DEV_OPT_OUT_PHONE = '+12025559999'
    DEV_SP_ISSUER = 'urn:gov:gsa:openidconnect:test:nds-explorer'

    # Registry of legacy pages whose before_actions need seeded DB/session state
    # (beyond a signed-in dev session) before they render. Maps the live route
    # path to a { label:, seeder:, resetter: } — the seeder is a private method
    # that provisions exactly what that page's guards demand (seed_state then
    # redirects to the page); the resetter tears that state back down so the
    # empty/redirect state can be tested. Add a page by registering it here.
    PAGE_STATES = {
      '/duplicate_profiles_detected' => {
        label: 'Seed duplicate profiles',
        seeder: :seed_duplicate_profiles_detected,
        resetter: :reset_duplicate_profiles_detected,
      },
      '/webauthn_setup_mismatch' => {
        label: 'Seed webauthn mismatch',
        seeder: :seed_webauthn_setup_mismatch,
        resetter: :reset_webauthn_setup_mismatch,
      },
      '/login/two_factor/piv_cac_mismatch' => {
        label: 'Seed PIV/CAC mismatch',
        seeder: :seed_piv_cac_mismatch,
        resetter: :reset_piv_cac_mismatch,
      },
      '/account/connected_services' => {
        label: 'Seed connected services',
        seeder: :seed_connected_services,
        resetter: :reset_connected_services,
      },
    }.freeze

    # Service providers seeded for the connected-services page: a distinct issuer
    # each so the account page lists multiple realistic connected apps.
    CONNECTED_SP_ISSUERS = [
      { issuer: 'urn:gov:gsa:openidconnect:test:nds-explorer-sp-a', name: 'NDS Dev App A' },
      { issuer: 'urn:gov:gsa:openidconnect:test:nds-explorer-sp-b', name: 'NDS Dev App B' },
    ].freeze

    # Maps a parameterized template to the record-kind key in record_specs. The
    # route segment is always ":id" (ambiguous), so the index tags each select
    # with this stable kind for delete/option lookup while the segment name still
    # drives URL substitution. Uniquely-named params are their own kind.
    TEMPLATE_RECORD_KINDS = {
      '/manage/phone/:id' => 'phone',
      '/manage/webauthn/:id' => 'webauthn',
      '/manage/piv_cac/:id' => 'piv_cac',
      '/manage/auth_app/:id' => 'auth_app',
      '/manage/email/confirm_delete/:id' => 'email',
      '/account/devices/:id/events' => 'device',
    }.freeze

    # Record kinds that back a real deletable model (i.e. keys of record_specs).
    # Uniquely-named route params that are not records (e.g. :source) are absent
    # so the index omits their delete button.
    DELETABLE_RECORD_KINDS = (
      TEMPLATE_RECORD_KINDS.values + %w[sp_id identity_id opt_out_uuid]
    ).freeze

    # Identity/proofing levels a developer can put the dev user into, to test how
    # pages behave for unverified vs IAL1 vs IAL2 (and its proofing variants) and
    # the reentrant pending flows. Each maps to a setter method; :detect reports
    # whether the user is currently at that level for the index status display.
    # Ordered as the dropdown should render.
    IDENTITY_LEVELS = [
      { key: 'unverified', label: 'Unverified (IAL1, no profile)' },
      { key: 'ial2', label: 'IAL2 verified (legacy)' },
      { key: 'ial2_facial_match', label: 'IAL2 verified (facial match)' },
      { key: 'in_person_verified', label: 'IAL2 verified (in-person)' },
      { key: 'in_person_pending', label: 'In-person pending (reentrant)' },
      { key: 'gpo_pending', label: 'Verify-by-mail pending (reentrant)' },
      { key: 'fraud_review_pending', label: 'Fraud review pending' },
    ].freeze

    before_action :require_test_routes_enabled
    before_action :require_dev_or_test_env,
                  only: %i[seed_session generate_mfa record_options delete_record
                           seed_state reset_state set_identity_level sign_out_dev]

    helper_method :nds_layout?, :decorated_sp_session, :current_sp, :current_user,
                  :desktop_device?, :enabled_mfa_methods_count,
                  :in_multi_mfa_selection_flow?, :in_account_creation_flow?,
                  :resource, :resource_name, :session_path, :page_state_for,
                  :record_kind_for, :deletable_record_kind?,
                  :identity_levels, :current_identity_level

    def index
      @grouped_pages = NDSPageCatalog.grouped
      @inventory = NDSPageCatalog.inventory
      @dev_user = warden_user
      render layout: false
    end

    def show
      @page = NDSPageCatalog.find(params[:page])
      return render_not_found if @page.nil?

      locals = send(:"setup_#{@page.key.tr('-', '_')}")
      render template: @page.template, locals: locals || {}
    end

    # Seeds a fully-registered, 2FA-authenticated dev session so the deep-linked
    # legacy pages (account/manage/IdV) render instead of bouncing to sign-in.
    # Devise's sign_in establishes the Warden user; the app then gates on
    # user_fully_authenticated?, which reads session['warden.user.user.session']
    # for auth_events + the NEED_AUTHENTICATION flag (see AuthMethodsSession and
    # ApplicationController#user_fully_authenticated?). We set those directly,
    # mirroring spec/support/features/session_helper.rb#sign_in_with_warden.
    def seed_session
      user = find_or_create_dev_user
      sign_in(user)
      warden_session = (session['warden.user.user.session'] ||= {}).with_indifferent_access
      warden_session[TwoFactorAuthenticatable::NEED_AUTHENTICATION] = false
      warden_session[:auth_events] =
        [{ auth_method: TwoFactorAuthenticatable::AuthMethod::SMS, at: Time.zone.now }]
      session['warden.user.user.session'] = warden_session
      redirect_to test_nds_path
    end

    # Seeds one of each record the parameterized legacy routes need, then
    # returns the full option catalog so the index can render dropdowns.
    def generate_mfa
      user = find_or_create_dev_user
      seed_dev_records(user)
      render json: dev_record_options(user)
    end

    # Returns the current option catalog without seeding (used on page load and
    # to refresh the dropdowns after a delete). Read-only: never creates the dev
    # user, so a GET has no side effects. Empty catalog when not signed in.
    def record_options
      user = warden_user
      return render(json: { by_template: {}, by_param: {} }) if user.nil?

      render json: dev_record_options(user)
    end

    # Deletes a single seeded record (by param + id) so a developer can test the
    # empty/404 states, then returns the refreshed option catalog.
    def delete_record
      user = warden_user || find_or_create_dev_user
      destroy_dev_record(user, params[:param], params[:id])
      render json: dev_record_options(user)
    end

    # Seeds the DB/session state a specific gated legacy page requires, then
    # redirects to it. Requires an already-seeded dev session (the target pages
    # sit behind confirm_two_factor_authenticated). warden_user is used rather
    # than the fabricated current_user this controller exposes for render-only.
    def seed_state
      user = warden_user
      return render_not_found if user.nil?

      state = PAGE_STATES[params[:path]]
      return render_not_found if state.nil?

      send(state[:seeder], user)
      redirect_to params[:path]
    end

    # Tears down the state a page's seeder provisioned so the empty/redirect
    # state can be tested, then returns to the index.
    def reset_state
      user = warden_user
      return render_not_found if user.nil?

      state = PAGE_STATES[params[:path]]
      return render_not_found if state.nil? || state[:resetter].nil?

      send(state[:resetter], user)
      redirect_to test_nds_path
    end

    def sign_out_dev
      sign_out(:user)
      redirect_to test_nds_path
    end

    # Reshapes the dev user's profiles/enrollments to the requested identity
    # level so pages can be tested at every proofing state, then returns to the
    # index. Always starts from a clean slate (destroys existing profiles +
    # enrollments) so the resulting state is deterministic.
    def set_identity_level
      user = warden_user
      return render_not_found if user.nil?

      level = params[:level]
      return render_not_found unless IDENTITY_LEVELS.any? { |l| l[:key] == level }

      apply_identity_level(user, level)
      redirect_to test_nds_path
    end

    def page_state_for(path)
      PAGE_STATES[path]
    end

    def identity_levels
      IDENTITY_LEVELS
    end

    # Best-effort label of the dev user's current identity level for the index.
    def current_identity_level(user)
      return 'unverified' if user.nil?
      return 'in_person_pending' if user.in_person_enrollments.exists?(status: :pending)
      return 'gpo_pending' if user.profiles.where.not(gpo_verification_pending_at: nil).exists?
      if user.profiles.where.not(fraud_review_pending_at: nil).exists?
        return 'fraud_review_pending'
      end

      active = user.profiles.find_by(active: true)
      return 'unverified' if active.nil?
      return 'in_person_verified' if active.idv_level == 'in_person'
      return 'ial2_facial_match' if active.facial_match?

      'ial2'
    end

    # Resolves the record-kind key for a template + segment name: the shared
    # ":id" maps via TEMPLATE_RECORD_KINDS; uniquely-named params are their own
    # kind. Used by the index to tag each select for delete/option lookup.
    def record_kind_for(template, param)
      return param unless param == 'id'

      TEMPLATE_RECORD_KINDS[template]
    end

    def deletable_record_kind?(kind)
      DELETABLE_RECORD_KINDS.include?(kind)
    end

    def nds_layout?
      true
    end

    def decorated_sp_session
      @decorated_sp_session ||= NullServiceProviderSession.new(view_context:)
    end

    def current_sp
      @current_sp
    end

    def current_user
      @nds_current_user
    end

    def user_session
      @user_session ||= {}
    end

    def desktop_device?
      @desktop_device.nil? || @desktop_device
    end

    def enabled_mfa_methods_count
      return 0 if current_user.nil?

      MfaContext.new(current_user).enabled_mfa_methods_count
    end

    def in_multi_mfa_selection_flow?
      @in_multi_mfa_selection_flow || false
    end

    def in_account_creation_flow?
      @in_account_creation_flow || false
    end

    def resource
      @resource
    end

    def resource_name
      :user
    end

    def session_path(_resource_name = nil)
      new_user_session_path
    end

    private

    def require_test_routes_enabled
      render_not_found unless IdentityConfig.store.enable_test_routes
    end

    def require_dev_or_test_env
      render_not_found unless Rails.env.local?
    end

    def warden_user
      request.env['warden']&.user(:user)
    end

    # Builds a confirmed, fully-registered, phone-2FA dev user with plain model
    # writes (factory_bot is test-only, so no create(:user) here). Replicates the
    # essential writes of the :fully_registered + :with_phone factory traits.
    def find_or_create_dev_user(email: DEV_USER_EMAIL)
      existing = EmailAddress.find_with_email(email)&.user
      return existing if existing

      now = Time.zone.now
      user = User.new(password: DEV_USER_PASSWORD, confirmed_at: now, accepted_terms_at: now)
      user.email = email
      user.email_addresses.build(
        email: email, confirmed_at: now,
        confirmation_sent_at: now
      )
      user.save!
      user.phone_configurations.create!(
        phone: DEV_PHONE, confirmed_at: now, delivery_preference: :sms, mfa_enabled: true,
      )
      user.create_registration_log(registered_at: now)
      user
    end

    # The parameterized legacy routes reference records by either a per-template
    # ":id" (ambiguous across templates) or a uniquely-named param. The hash keys
    # identify each record kind in the option catalog; :collection resolves the
    # user's records, :value maps a record to its route value, :label to a human
    # label. The index binds each ":id" select to a template via :templates and
    # uniquely-named selects via :params.
    def record_specs(user)
      {
        'phone' => {
          templates: ['/manage/phone/:id'],
          collection: user.phone_configurations,
          value: ->(r) { r.id },
          label: ->(r) { "phone ##{r.id}" },
        },
        'webauthn' => {
          templates: ['/manage/webauthn/:id'],
          collection: user.webauthn_configurations,
          value: ->(r) { r.id },
          label: ->(r) { "#{r.name} (##{r.id})" },
        },
        'piv_cac' => {
          templates: ['/manage/piv_cac/:id'],
          collection: user.piv_cac_configurations,
          value: ->(r) { r.id },
          label: ->(r) { "#{r.name} (##{r.id})" },
        },
        'auth_app' => {
          templates: ['/manage/auth_app/:id'],
          collection: user.auth_app_configurations,
          value: ->(r) { r.id },
          label: ->(r) { "#{r.name} (##{r.id})" },
        },
        'email' => {
          templates: ['/manage/email/confirm_delete/:id'],
          collection: user.email_addresses,
          value: ->(r) { r.id },
          label: ->(r) { "#{r.email} (##{r.id})" },
        },
        'device' => {
          templates: ['/account/devices/:id/events'],
          collection: user.devices,
          value: ->(r) { r.id },
          label: ->(r) { "device ##{r.id}" },
        },
        'sp_id' => {
          params: ['sp_id'],
          collection: ServiceProvider.where(issuer: DEV_SP_ISSUER),
          value: ->(r) { r.id },
          label: ->(r) { "#{r.friendly_name} (##{r.id})" },
        },
        'identity_id' => {
          params: ['identity_id'],
          collection: user.identities,
          value: ->(r) { r.id },
          label: ->(r) { "identity ##{r.id}" },
        },
        'opt_out_uuid' => {
          params: ['opt_out_uuid'],
          collection: PhoneNumberOptOut.where(phone_fingerprint: dev_opt_out_fingerprint),
          value: ->(r) { r.uuid },
          label: ->(r) { "opt-out #{r.uuid}" },
        },
      }
    end

    # Creates one of each record type if the dev user has none, so the dropdowns
    # start non-empty. Idempotent: existing records are reused.
    def seed_dev_records(user)
      now = Time.zone.now
      user.phone_configurations.first ||
        user.phone_configurations.create!(
          phone: DEV_PHONE, confirmed_at: now, delivery_preference: :sms, mfa_enabled: true,
        )
      user.webauthn_configurations.first ||
        user.webauthn_configurations.create!(
          name: 'NDS dev key', credential_id: SecureRandom.hex(16),
          credential_public_key: SecureRandom.hex(16), transports: ['usb']
        )
      user.piv_cac_configurations.first ||
        user.piv_cac_configurations.create!(name: 'NDS dev PIV', x509_dn_uuid: SecureRandom.uuid)
      user.auth_app_configurations.first ||
        user.auth_app_configurations.create!(
          name: 'NDS dev app', otp_secret_key: ROTP::Base32.random_base32,
        )
      primary_email_id = user.email_addresses.order(:id).first&.id
      user.email_addresses.where.not(id: primary_email_id).first ||
        user.email_addresses.create!(
          email: 'nds-dev-extra@example.com', confirmed_at: now, confirmation_sent_at: now,
        )
      user.devices.first ||
        user.devices.create!(
          cookie_uuid: SecureRandom.hex(32), user_agent: 'NDS explorer dev',
          last_used_at: now, last_ip: '127.0.0.1'
        )
      service_provider = dev_service_provider
      user.identities.where(service_provider: service_provider.issuer).first ||
        user.identities.create!(
          service_provider: service_provider.issuer, uuid: SecureRandom.uuid,
          last_authenticated_at: Time.zone.now
        )
      PhoneNumberOptOut.create_or_find_with_phone(DEV_OPT_OUT_PHONE)
    end

    # Builds the dropdown catalog. Each entry lists the real record options plus
    # synthetic "(none / blank)" and "(invalid)" choices so the empty and 404
    # states can be exercised. by_template resolves the shared ":id" segment;
    # by_param covers uniquely-named segments.
    def dev_record_options(user)
      by_template = {}
      by_param = {}
      extra = [{ value: '', label: '(none / blank)' }, { value: '0', label: '(invalid)' }]

      record_specs(user).each_value do |spec|
        options = spec[:collection].map do |record|
          { value: spec[:value].call(record).to_s, label: spec[:label].call(record) }
        end + extra
        Array(spec[:templates]).each { |template| by_template[template] = options }
        Array(spec[:params]).each { |param| by_param[param] = options }
      end

      by_param['source'] = %w[dont_recognize cant_access].map do |source|
        { value: source, label: source }
      end + [{ value: 'invalid_source', label: '(invalid)' }]

      { by_template:, by_param: }
    end

    def destroy_dev_record(user, param, id)
      spec = record_specs(user)[param]
      return if spec.nil? || id.blank?

      collection = spec[:collection]
      record = collection.find_by(id:) if id.match?(/\A\d+\z/)
      if record.nil? && collection.model.column_names.include?('uuid')
        record = collection.find_by(uuid: id)
      end
      record&.destroy
    end

    def dev_opt_out_fingerprint
      Pii::Fingerprinter.fingerprint(PhoneNumberOptOut.normalize(DEV_OPT_OUT_PHONE))
    end

    def dev_agency
      Agency.find_by(name: 'NDS Explorer Dev Agency') || Agency.first ||
        Agency.create!(name: 'NDS Explorer Dev Agency', abbreviation: "NDS#{SecureRandom.hex(2)}")
    end

    def dev_service_provider
      ServiceProvider.find_by(issuer: DEV_SP_ISSUER) ||
        ServiceProvider.create!(
          issuer: DEV_SP_ISSUER, friendly_name: 'NDS Explorer Dev SP', agency: dev_agency,
        )
    end

    def active_facial_match_profile(user)
      user.profiles.where(active: true).first ||
        user.profiles.create!(
          active: true, activated_at: Time.zone.now, verified_at: Time.zone.now,
          idv_level: :unsupervised_with_selfie
        )
    end

    # duplicate_profiles_detected#show requires: an active facial-match profile,
    # an open DuplicateProfileSet involving it, and a current_sp in session.
    def seed_duplicate_profiles_detected(user)
      service_provider = dev_service_provider
      session[:sp] = {
        issuer: service_provider.issuer,
        acr_values: Saml::Idp::Constants::IAL_AUTH_ONLY_ACR,
      }
      profile = active_facial_match_profile(user)
      other_profile = active_facial_match_profile(
        find_or_create_dev_user(email: DEV_DUPLICATE_EMAIL),
      )
      # Match the detection mode the page reads: global sets have a nil
      # service_provider, SP-scoped sets carry the issuer.
      global = IdentityConfig.store.enable_one_account_global_detection
      set_issuer = global ? nil : service_provider.issuer
      existing = if global
                   DuplicateProfileSet.involving_profile_global(profile_id: profile.id)
                 else
                   DuplicateProfileSet.involving_profile(
                     profile_id: profile.id, service_provider: set_issuer,
                   )
                 end
      return if existing

      DuplicateProfileSet.create!(
        profile_ids: [profile.id, other_profile.id],
        service_provider: set_issuer,
      )
    end

    # Removes the duplicate-profile state (sets + seeded profiles + the SP
    # session) so the page redirects to root again.
    def reset_duplicate_profiles_detected(user)
      session.delete(:sp)
      dupe_user = EmailAddress.find_with_email(DEV_DUPLICATE_EMAIL)&.user
      profile_ids = [user, dupe_user].compact.flat_map { |u| u.profiles.pluck(:id) }
      profile_ids.each do |profile_id|
        DuplicateProfileSet.duplicate_profile_sets_for_profile(profile_id:).destroy_all
      end
      user.profiles.destroy_all
      dupe_user&.profiles&.destroy_all
    end

    # Reads, mutates, and writes back the Warden user session hash (the same
    # store ApplicationController#user_session exposes) so seeded session keys
    # survive to the target page's request.
    def merge_warden_user_session(attrs)
      warden_session = (session['warden.user.user.session'] ||= {}).with_indifferent_access
      warden_session.merge!(attrs)
      session['warden.user.user.session'] = warden_session
    end

    # webauthn_setup_mismatch#show requires a recent 2FA session (dev session has
    # it) plus user_session[:webauthn_mismatch_id] pointing at a real webauthn
    # configuration; validate_session_mismatch_id redirects away otherwise.
    def seed_webauthn_setup_mismatch(user)
      configuration = user.webauthn_configurations.first ||
                      user.webauthn_configurations.create!(
                        name: 'NDS dev key', credential_id: SecureRandom.hex(16),
                        credential_public_key: SecureRandom.hex(16), transports: ['usb']
                      )
      merge_warden_user_session(webauthn_mismatch_id: configuration.id)
    end

    def reset_webauthn_setup_mismatch(_user)
      merge_warden_user_session(webauthn_mismatch_id: nil)
    end

    # piv_cac_mismatch#show is a mid-authentication page: check_already_authenticated
    # redirects a fully-authenticated user away only in the authentication context.
    # The dev session is fully authenticated, so switch its context to
    # reauthentication (same view, no redirect) rather than downgrading 2FA.
    def seed_piv_cac_mismatch(_user)
      merge_warden_user_session(context: UserSessionContext::REAUTHENTICATION_CONTEXT)
    end

    def reset_piv_cac_mismatch(_user)
      merge_warden_user_session(context: UserSessionContext::AUTHENTICATION_CONTEXT)
    end

    # account/connected_services lists the user's non-deleted identities joined to
    # their service_provider_record. Seeds one identity per CONNECTED_SP_ISSUERS
    # entry, each with a confirmed email association and verified attributes, so
    # the page renders realistic connected apps (with revoke + change-email links).
    def seed_connected_services(user)
      email = user.email_addresses.confirmed.first || user.email_addresses.first
      CONNECTED_SP_ISSUERS.each do |sp|
        service_provider = connected_service_provider(sp)
        identity = user.identities.find_or_initialize_by(service_provider: service_provider.issuer)
        identity.update!(
          uuid: identity.uuid || SecureRandom.uuid,
          last_authenticated_at: Time.zone.now,
          last_consented_at: Time.zone.now,
          deleted_at: nil,
          email_address: email,
          verified_attributes: %w[email],
        )
      end
    end

    def reset_connected_services(user)
      issuers = CONNECTED_SP_ISSUERS.map { |sp| sp[:issuer] }
      user.identities.where(service_provider: issuers).destroy_all
    end

    def connected_service_provider(sp)
      ServiceProvider.find_by(issuer: sp[:issuer]) ||
        ServiceProvider.create!(
          issuer: sp[:issuer], friendly_name: sp[:name],
          return_to_sp_url: root_url, agency: dev_agency
        )
    end

    # Clears the dev user's active-profile cache and destroys all profiles +
    # in-person enrollments, then builds the requested level from scratch.
    def apply_identity_level(user, level)
      user.in_person_enrollments.destroy_all
      user.profiles.destroy_all
      user.instance_variable_set(:@active_profile, nil)

      case level
      when 'ial2'
        build_verified_profile(user, idv_level: :legacy_unsupervised)
      when 'ial2_facial_match'
        build_verified_profile(user, idv_level: :unsupervised_with_selfie)
      when 'in_person_verified'
        build_verified_profile(user, idv_level: :in_person)
      when 'in_person_pending' then build_in_person_pending(user)
      when 'gpo_pending' then build_gpo_pending(user)
      when 'fraud_review_pending' then build_fraud_review_pending(user)
      end
    end

    # Builds an active, verified profile carrying real encrypted PII so pages
    # that decrypt it (account, connected accounts) work.
    def build_verified_profile(user, idv_level:, **attrs)
      now = Time.zone.now
      profile = user.profiles.new(
        active: true, activated_at: now, verified_at: now, idv_level:, **attrs,
      )
      encrypt_dev_pii(profile)
      profile.save!
      profile
    end

    # A pending in-person enrollment + its non-active pending profile — the state
    # a user re-enters the in-person proofing flow from.
    def build_in_person_pending(user)
      now = Time.zone.now
      profile = user.profiles.new(
        active: false, idv_level: :in_person, in_person_verification_pending_at: now,
      )
      encrypt_dev_pii(profile)
      profile.save!
      user.in_person_enrollments.create!(
        profile:, status: :pending, enrollment_code: dev_enrollment_code,
        enrollment_established_at: now, status_updated_at: now,
        current_address_matches_id: true, unique_id: InPersonEnrollment.generate_unique_id,
        sponsor_id: IdentityConfig.store.usps_ipp_sponsor_id
      )
      profile
    end

    # The ready_to_verify barcode is Code128C, which requires an even-length
    # numeric string, so a hex code would raise "Data not valid".
    def dev_enrollment_code
      SecureRandom.random_number(10 ** 16).to_s.rjust(16, '0')
    end

    def build_gpo_pending(user)
      profile = user.profiles.new(
        active: false, idv_level: :legacy_unsupervised,
        gpo_verification_pending_at: Time.zone.now
      )
      encrypt_dev_pii(profile)
      profile.save!
      profile
    end

    def build_fraud_review_pending(user)
      profile = user.profiles.new(
        active: false, idv_level: :legacy_unsupervised,
        fraud_pending_reason: 'threatmetrix_review', fraud_review_pending_at: Time.zone.now
      )
      encrypt_dev_pii(profile)
      profile.save!
      profile
    end

    def encrypt_dev_pii(profile)
      pii = Pii::Attributes.new_from_hash(Idp::Constants::MOCK_IDV_APPLICANT_WITH_PHONE)
      profile.encrypt_pii(pii, DEV_USER_PASSWORD)
    end

    def setup_sign_in
      @resource = User.new
      error = params[:error]
      if error == 'email' || error == 'both'
        @resource.errors.add(:email, t('valid_email.validations.email.invalid'))
      end
      if error == 'password' || error == 'both'
        @resource.errors.add(:password, t('errors.messages.blank'))
      end

      @issuer_forced_reauthentication = params[:reauth].present?
      @desktop_device = params[:device] != 'mobile'

      if params[:sp].present?
        @decorated_sp_session = SpSessionStub.new(
          sp_name: 'Example Service Provider',
          sp_alert_text: params[:sp_alert].present? ? 'Example service provider alert.' : nil,
          cancel_link_url: root_url,
        )
      end
      if params[:logo].present?
        @current_sp = ServiceProviderStub.new(
          logo: 'logo.svg',
          logo_url: image_path('logo.svg'),
          issuer: 'urn:gov:gsa:test',
        )
      end
      {}
    end

    def setup_piv_cac
      @presenter = PivCacAuthenticationLoginPresenter.new(nil, url_options)
      {}
    end

    def setup_create_account
      @register_user_email_form = RegisterUserEmailForm.new(analytics:, attempts_api_tracker:)
      if params[:error] == 'email'
        @register_user_email_form.errors.add(:email, t('valid_email.validations.email.invalid'))
      end
      if params[:sp_alert].present?
        @decorated_sp_session = SpSessionStub.new(
          sp_name: 'Example Service Provider',
          sp_alert_text: 'Example service provider alert.',
          cancel_link_url: root_url,
        )
      end
      {}
    end

    def setup_verify_email
      email = 'user@example.com'
      @resend_confirmation = params[:resend].present?
      @resend_email_confirmation_form = ResendEmailConfirmationForm.new(
        email:, terms_accepted: true,
      )
      { email: }
    end

    def setup_enter_password
      user = User.new
      @password_form = PasswordForm.new(user:)
      if params[:error].present?
        @password_form.errors.add(:password, t('errors.messages.too_short.other', count: 12))
      end
      @email_address = EmailAddressStub.new(email: 'user@example.com')
      @confirmation_token = 'test-confirmation-token'
      @forbidden_passwords = []
      flash.now[:success] = t('devise.confirmations.confirmed_but_must_set_password') if
        params[:toast].present?
      {}
    end

    def setup_mfa_setup
      user = build_mfa_user(configured: params[:second].present?)
      @nds_current_user = user
      phishing_resistant_required = params[:phishing].present?
      piv_cac_required = params[:piv_cac].present?
      @presenter = TwoFactorOptionsPresenter.new(
        user_agent: request.user_agent,
        user:,
        phishing_resistant_required:,
        piv_cac_required:,
        show_skip_additional_mfa_link: params[:skip].present?,
        after_mfa_setup_path: account_path,
        return_to_sp_cancel_path: root_path,
      )
      @two_factor_options_form = TwoFactorOptionsForm.new(
        user:, phishing_resistant_required:, piv_cac_required:,
      )
      # dev config enables account-creation device profiling (collect_only), so
      # the view renders the ThreatMetrix partial; supply the inert no-op locals
      # the real controller passes when no session is bootstrapped.
      ThreatMetrixHelper::NO_THREAT_METRIX_VARIABLES.dup
    end

    def setup_piv_cac_setup
      skip = params[:skip].present?
      user = build_mfa_user(configured: params[:second].present?)
      @nds_current_user = user
      @piv_cac_required = false
      @in_account_creation_flow = !skip
      user_session[:add_piv_cac_after_2fa] = true if skip
      @presenter = PivCacAuthenticationSetupPresenter.new(user, true, nil)
      {}
    end

    def setup_otp_entry
      @nds_current_user = User.new
      delivery = params[:delivery] == 'voice' ? 'voice' : 'sms'
      @landline_alert = params[:landline].present?
      @in_account_creation_flow = params[:account_creation].present?
      @presenter = TwoFactorAuthCode::PhoneDeliveryPresenter.new(
        data: {
          confirmation_for_add_phone: false,
          phone_number: '(202) 555-1212',
          code_value: params[:code].present? ? '123456' : nil,
          in_multi_mfa_selection_flow: false,
          otp_expiration: params[:countdown].present? ? 10.minutes.from_now : nil,
          otp_delivery_preference: delivery,
          otp_make_default_number: false,
          unconfirmed_phone: false,
          user_opted_remember_device_cookie: nil,
          reauthn: params[:reauthn].present?,
        },
        view: view_context,
        service_provider: nil,
        remember_device_default: true,
      )
      {}
    end

    def setup_totp_setup
      user = build_mfa_user(configured: params[:second].present?)
      @nds_current_user = user
      @in_account_creation_flow = params[:account_creation].present?
      email = EmailAddressStub.new(email: DEV_USER_EMAIL)
      user.define_singleton_method(:last_sign_in_email_address) { email }
      @code = user.generate_totp_secret
      @qrcode = user.qrcode(@code)
      @presenter = SetupPresenter.new(
        current_user: user,
        user_fully_authenticated: true,
        user_opted_remember_device_cookie: nil,
        remember_device_default: false,
      )
      {}
    end

    def setup_idv_welcome
      if params[:sp].present?
        @decorated_sp_session = SpSessionStub.new(
          sp_name: 'Example Service Provider',
          sp_alert_text: nil,
          cancel_link_url: root_url,
        )
      end
      if params[:logo].present?
        @current_sp = ServiceProviderStub.new(
          logo: 'logo.svg',
          logo_url: helpers.image_path('logo.svg'),
          issuer: DEV_SP_ISSUER,
        )
      end
      @presenter = Idv::WelcomePresenter.new(
        decorated_sp_session:,
        show_sp_reproof_banner: params[:reproof].present?,
        passport_cards_supported: true,
        mdl_enabled: true,
      )
      @consent_form = Idv::ConsentForm.new(idv_consent_given: false)
      {}
    end

    def setup_choose_id_type
      {
        presenter: Idv::ChooseIdTypePresenter.new,
        form_submit_url: '#',
        disable_passports: params[:no_passport].present?,
        auto_check_value: :state_id_card,
        passport_cards_enabled: params[:passport_card].present?,
        mdl_enabled: params[:mdl].present?,
        show_verify_in_person: params[:ipp].present?,
      }
    end

    def build_mfa_user(configured:)
      user = User.new
      if configured
        user.phone_configurations.build(
          phone: '+12025551212',
          confirmed_at: Time.zone.now,
          delivery_preference: :sms,
        )
      end
      user
    end
  end
end

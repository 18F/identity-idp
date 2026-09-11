# frozen_string_literal: true

module Test
  # Single source of truth for the dev-only NDS page-state explorer.
  # Both the index and the render action read from PAGES so the list can
  # never drift. Each page maps a slug to the real view template it renders
  # plus the visually-distinct permutations a developer may want to inspect.
  module NDSPageCatalog
    Permutation = Struct.new(:label, :params, keyword_init: true)
    Page = Struct.new(:key, :title, :flow, :template, :permutations, keyword_init: true)

    SIGN_IN = 'Sign in'
    CREATE_ACCOUNT = 'Create account'
    MFA = 'MFA'
    OTP = 'OTP'
    IDV = 'Identity verification'
    ERRORS = 'Errors'

    PAGES = [
      Page.new(
        key: 'sign-in',
        title: 'Sign in',
        flow: SIGN_IN,
        template: 'devise/sessions/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
          Permutation.new(label: 'SP + logo', params: { sp: '1', logo: '1' }),
          Permutation.new(label: 'SP alert', params: { sp: '1', sp_alert: '1' }),
          Permutation.new(label: 'Forced reauthentication', params: { sp: '1', reauth: '1' }),
          Permutation.new(label: 'Email error', params: { error: 'email' }),
          Permutation.new(label: 'Password error', params: { error: 'password' }),
          Permutation.new(label: 'Both errors', params: { error: 'both' }),
          Permutation.new(label: 'Mobile device', params: { device: 'mobile' }),
        ],
      ),
      Page.new(
        key: 'piv-cac',
        title: 'PIV/CAC sign in',
        flow: SIGN_IN,
        template: 'users/piv_cac_login/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'create-account',
        title: 'Create account (enter email)',
        flow: CREATE_ACCOUNT,
        template: 'sign_up/registrations/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'SP alert', params: { sp_alert: '1' }),
          Permutation.new(label: 'Email error', params: { error: 'email' }),
        ],
      ),
      Page.new(
        key: 'verify-email',
        title: 'Verify email',
        flow: CREATE_ACCOUNT,
        template: 'sign_up/emails/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Resend confirmation', params: { resend: '1' }),
        ],
      ),
      Page.new(
        key: 'enter-password',
        title: 'Enter password',
        flow: CREATE_ACCOUNT,
        template: 'sign_up/passwords/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Confirmation toast', params: { toast: '1' }),
          Permutation.new(label: 'Password error', params: { error: '1' }),
        ],
      ),
      Page.new(
        key: 'mfa-setup',
        title: 'Authentication methods setup',
        flow: MFA,
        template: 'users/two_factor_authentication_setup/index',
        permutations: [
          Permutation.new(label: 'First MFA', params: {}),
          Permutation.new(label: 'Second MFA (configured)', params: { second: '1' }),
          Permutation.new(label: 'Skip link', params: { second: '1', skip: '1' }),
          Permutation.new(label: 'Phishing resistant required', params: { phishing: '1' }),
          Permutation.new(label: 'PIV/CAC required', params: { piv_cac: '1' }),
        ],
      ),
      Page.new(
        key: 'piv-cac-setup',
        title: 'Add government employee ID (PIV/CAC)',
        flow: MFA,
        template: 'users/piv_cac_authentication_setup/new',
        permutations: [
          Permutation.new(label: 'First MFA', params: {}),
          Permutation.new(label: 'Second MFA (configured)', params: { second: '1' }),
          Permutation.new(label: 'Add after sign-in (skip)', params: { skip: '1' }),
        ],
      ),
      Page.new(
        key: 'totp-setup',
        title: 'Authentication app setup',
        flow: MFA,
        template: 'users/totp_setup/new',
        permutations: [
          Permutation.new(label: 'During sign-in (no stepper)', params: {}),
          Permutation.new(
            label: 'First MFA (account creation)',
            params: { account_creation: '1' },
          ),
          Permutation.new(
            label: 'Second MFA (account creation)',
            params: { account_creation: '1', second: '1' },
          ),
        ],
      ),
      Page.new(
        key: 'phone-setup',
        title: 'Add a phone number',
        flow: MFA,
        template: 'users/phone_setup/index',
        permutations: [
          Permutation.new(label: 'First MFA', params: {}),
          Permutation.new(label: 'Second MFA (configured)', params: { second: '1' }),
          Permutation.new(label: 'Voice preferred', params: { delivery: 'voice' }),
          Permutation.new(label: 'Sign-in (no stepper)', params: { flow: 'sign_in' }),
          Permutation.new(label: 'Phone error', params: { error: '1' }),
        ],
      ),
      Page.new(
        key: 'backup-code-delete',
        title: 'Delete backup codes',
        flow: MFA,
        template: 'users/backup_code_setup/confirm_delete',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'otp-entry',
        title: 'One-time code entry',
        flow: OTP,
        template: 'two_factor_authentication/otp_verification/show',
        permutations: [
          Permutation.new(label: 'SMS', params: {}),
          Permutation.new(label: 'Voice', params: { delivery: 'voice' }),
          Permutation.new(label: 'Landline alert', params: { landline: '1' }),
          Permutation.new(label: 'Countdown', params: { countdown: '1' }),
          Permutation.new(label: 'Reauthentication', params: { reauthn: '1' }),
          Permutation.new(label: 'Prefilled code', params: { code: '1' }),
          Permutation.new(label: 'Incorrect code', params: { error: '1', code: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-welcome',
        title: 'Verify your identity (welcome)',
        flow: IDV,
        template: 'idv/welcome/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
          Permutation.new(label: 'SP + logo', params: { sp: '1', logo: '1' }),
          Permutation.new(label: 'SP reproof banner', params: { sp: '1', reproof: '1' }),
        ],
      ),
      Page.new(
        key: 'choose-id-type',
        title: 'Choose your ID type',
        flow: IDV,
        template: 'idv/shared/choose_id_type',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With passport card', params: { passport_card: '1' }),
          Permutation.new(label: 'With mDL', params: { mdl: '1' }),
          Permutation.new(label: 'Verify in person', params: { ipp: '1' }),
          Permutation.new(label: 'Passports disabled', params: { no_passport: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-unavailable',
        title: 'Identity verification unavailable',
        flow: IDV,
        template: 'idv/unavailable/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'sp-inactive',
        title: 'Service provider inactive',
        flow: ERRORS,
        template: 'users/service_provider_inactive/index',
        permutations: [
          Permutation.new(label: 'Generic service provider', params: {}),
          Permutation.new(label: 'Named service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'duplicate-profiles-detected',
        title: 'Duplicate profiles detected',
        flow: SIGN_IN,
        template: 'duplicate_profiles_detected/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Duplicate never signed in', params: { never: '1' }),
        ],
      ),
      Page.new(
        key: 'banned-user',
        title: 'Account banned',
        flow: ERRORS,
        template: 'banned_user/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'device-profiling-failed',
        title: 'Device profiling failed',
        flow: ERRORS,
        template: 'device_profiling_failed/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'security-check-failed',
        title: 'Sign-in security check failed',
        flow: ERRORS,
        template: 'sign_in_security_check_failed/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'proofing-agent-expired',
        title: 'Proofing agent session expired',
        flow: ERRORS,
        template: 'idv/proofing_agent_expired/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'mail-only-warning',
        title: 'Verify by mail only (phone outage)',
        flow: ERRORS,
        template: 'idv/mail_only_warning/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'session-error-warning',
        title: 'Verify info warning (attempts remaining)',
        flow: ERRORS,
        template: 'idv/session_errors/warning',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Last attempt', params: { attempts: '1' }),
        ],
      ),
      Page.new(
        key: 'session-error-address-warning',
        title: 'Address warning (attempts remaining)',
        flow: ERRORS,
        template: 'idv/session_errors/address_warning',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Last attempt', params: { attempts: '1' }),
        ],
      ),
      Page.new(
        key: 'vendor-outage',
        title: 'Vendor outage',
        flow: ERRORS,
        template: 'vendor_outage/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With verify-by-mail option', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'please-call',
        title: 'Please call (suspended account)',
        flow: ERRORS,
        template: 'users/please_call/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'idv-please-call',
        title: 'Please call (fraud review)',
        flow: ERRORS,
        template: 'idv/please_call/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'In person (no stepper)', params: { ipp: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-not-verified',
        title: 'Information not verified',
        flow: ERRORS,
        template: 'idv/not_verified/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'session-error-failure',
        title: 'Verify info failure (rate limited)',
        flow: ERRORS,
        template: 'idv/session_errors/failure',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'session-error-exception',
        title: 'Verify info exception',
        flow: ERRORS,
        template: 'idv/session_errors/exception',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'session-error-rate-limited',
        title: 'Document capture rate limited',
        flow: ERRORS,
        template: 'idv/session_errors/rate_limited',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'session-error-state-id-warning',
        title: 'State ID warning',
        flow: ERRORS,
        template: 'idv/session_errors/state_id_warning',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'socure-errors',
        title: 'Socure document capture error',
        flow: ERRORS,
        template: 'idv/socure/errors/show',
        permutations: [
          Permutation.new(label: 'Network', params: {}),
          Permutation.new(label: 'Timeout', params: { code: 'timeout' }),
          Permutation.new(label: 'Unaccepted ID type', params: { code: 'unaccepted_id_type' }),
          Permutation.new(label: 'Selfie failed', params: { code: 'selfie_fail' }),
        ],
      ),
      Page.new(
        key: 'hybrid-socure-errors',
        title: 'Socure document capture error (hybrid mobile)',
        flow: ERRORS,
        template: 'idv/hybrid_mobile/socure/errors/show',
        permutations: [
          Permutation.new(label: 'Network', params: {}),
          Permutation.new(label: 'Timeout', params: { code: 'timeout' }),
        ],
      ),
      Page.new(
        key: 'socure-document-capture-errors',
        title: 'Socure document capture error (legacy route)',
        flow: ERRORS,
        template: 'idv/socure/document_capture/errors',
        permutations: [
          Permutation.new(label: 'Network', params: {}),
        ],
      ),
      Page.new(
        key: 'hybrid-socure-document-capture-errors',
        title: 'Socure document capture error (hybrid, legacy route)',
        flow: ERRORS,
        template: 'idv/hybrid_mobile/socure/document_capture/errors',
        permutations: [
          Permutation.new(label: 'Network', params: {}),
        ],
      ),
      Page.new(
        key: 'enter-code-rate-limited',
        title: 'Verify by mail code rate limited',
        flow: ERRORS,
        template: 'idv/by_mail/enter_code_rate_limited/index',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'confirm-start-over',
        title: 'Confirm start over (verify by mail)',
        flow: ERRORS,
        template: 'idv/confirm_start_over/index',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'confirm-start-over-before-letter',
        title: 'Confirm start over (before letter)',
        flow: ERRORS,
        template: 'idv/confirm_start_over/before_letter',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'duplicate-profiles-please-call',
        title: 'Duplicate profiles please call',
        flow: ERRORS,
        template: 'users/duplicate_profiles_please_call/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
        ],
      ),
      Page.new(
        key: 'phone-error-failure',
        title: 'Phone verification failure (rate limited)',
        flow: ERRORS,
        template: 'idv/phone_errors/failure',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Verify by mail available', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'phone-error-warning',
        title: 'Phone verification warning',
        flow: ERRORS,
        template: 'idv/phone_errors/warning',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Verify by mail available', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'hybrid-handoff',
        title: 'Send a link to your phone (hybrid handoff)',
        flow: IDV,
        template: 'idv/hybrid_handoff/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Desktop upload enabled', params: { upload: '1' }),
        ],
      ),
      Page.new(
        key: 'link-sent',
        title: 'Continue on your phone (link sent)',
        flow: IDV,
        template: 'idv/link_sent/show',
        permutations: [Permutation.new(label: 'Default', params: {})],
      ),
      Page.new(
        key: 'capture-complete',
        title: 'Switch back to your computer (mobile)',
        flow: IDV,
        template: 'idv/hybrid_mobile/capture_complete/show',
        permutations: [Permutation.new(label: 'Default', params: {})],
      ),
      Page.new(
        key: 'idv-ssn',
        title: 'Enter your Social Security number',
        flow: IDV,
        template: 'idv/shared/ssn',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Updating SSN', params: { update: '1' }),
          Permutation.new(label: 'With service provider', params: { sp: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-address',
        title: 'Enter your residential address',
        flow: IDV,
        template: 'idv/address/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Updating address', params: { update: '1' }),
          Permutation.new(label: 'Mailing address (letter)', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-verify-info',
        title: 'Verify your information',
        flow: IDV,
        template: 'idv/verify_info/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Barcode read failure', params: { barcode: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-enter-password',
        title: 'Re-enter your password',
        flow: IDV,
        template: 'idv/enter_password/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Phone verified toast', params: { toast: '1' }),
          Permutation.new(label: 'Verify by mail', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-phone',
        title: 'Verify your phone number',
        flow: IDV,
        template: 'idv/phone/new',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'Verify by mail available', params: { gpo: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-phone-confirmation',
        title: 'Enter your one-time code (IdV)',
        flow: IDV,
        template: 'idv/otp_verification/show',
        permutations: [
          Permutation.new(label: 'SMS', params: {}),
          Permutation.new(label: 'Voice', params: { delivery: 'voice' }),
          Permutation.new(label: 'Invalid code', params: { error: '1' }),
        ],
      ),
      Page.new(
        key: 'idv-request-letter',
        title: 'Verify by mail instead (request letter)',
        flow: IDV,
        template: 'idv/by_mail/request_letter/index',
        permutations: [Permutation.new(label: 'Default', params: {})],
      ),
      Page.new(
        key: 'idv-personal-key',
        title: 'Save your personal key',
        flow: IDV,
        template: 'idv/personal_key/show',
        permutations: [
          Permutation.new(label: 'Default', params: {}),
          Permutation.new(label: 'With toast', params: { toast: '1' }),
        ],
      ),
      Page.new(
        key: 'completions',
        title: 'Identity verified (share information / consent)',
        flow: IDV,
        template: 'sign_up/completions/show',
        permutations: [
          Permutation.new(label: 'Verified identity', params: {}),
          Permutation.new(label: 'Auth only (new SP)', params: { auth: '1' }),
          Permutation.new(label: 'Single MFA warning', params: { single: '1' }),
        ],
      ),
    ].freeze

    def self.pages
      PAGES
    end

    def self.find(key)
      PAGES.find { |page| page.key == key }
    end

    def self.grouped
      PAGES.group_by(&:flow)
    end

    # NDS pages that render under the NDS layout without an `nds_layout?`
    # branch in their template, so the template scan below cannot detect them.
    # Kept explicit and minimal; unioned into the discovered set.
    BRANCHLESS_NDS_TEMPLATES = [
      'sign_up/emails/show',
      'two_factor_authentication/otp_verification/show',
      'users/piv_cac_login/new',
    ].freeze

    # Dynamic single source of truth for NDS-page completeness: the set of
    # view templates is scanned at runtime rather than hardcoded. A template is
    # an NDS page if it contains an `nds_layout?` conditional (its authoritative
    # NDS-bucket branch) either directly or via a shared partial it renders
    # (one level, e.g. `render 'idv/shared/error'`), plus the explicit
    # branchless allowlist above. Scanning templates is preferred over
    # resolving every route's render target because render resolution is
    # unreliable for non-conventional actions.
    def self.discovered_templates
      scanned = Rails.root.glob('app/views/**/*.html.erb').filter_map do |path|
        rel = path.relative_path_from(Rails.root.join('app/views')).to_s
        template = rel.delete_suffix('.html.erb')
        next if File.basename(template).start_with?('_')
        next if template.start_with?('layouts/')
        next unless nds_branch_source?(path)

        template
      end
      (scanned + BRANCHLESS_NDS_TEMPLATES).uniq.sort
    end

    def self.template_exists?(template)
      Rails.root.join('app/views', "#{template}.html.erb").exist?
    end

    def self.branch_template?(template)
      path = Rails.root.join('app/views', "#{template}.html.erb")
      path.exist? && nds_branch_source?(path)
    end

    RENDER_PARTIAL_PATTERN = /render\(?\s*(?:partial:\s*)?['"]([\w\/]+)['"]/

    # True when the template carries an `nds_layout?` branch itself or renders
    # a shared partial that does. Only one level of indirection is followed:
    # that covers the shared status/error partials without turning the scan
    # into a full render-graph walk.
    def self.nds_branch_source?(path)
      source = path.read
      return true if source.include?('nds_layout?')

      source.scan(RENDER_PARTIAL_PATTERN).flatten.any? do |partial|
        dir, base = File.split(partial)
        partial_path = Rails.root.join('app/views', dir, "_#{base}.html.erb")
        partial_path.exist? && partial_path.read.include?('nds_layout?')
      end
    end

    # Cross-check the dynamically discovered NDS templates against PAGES so the
    # explorer is self-auditing:
    #   covered: catalog templates that are still valid NDS pages
    #   missing: discovered NDS templates absent from the catalog (coverage gap)
    #   stale:   catalog templates that no longer exist or dropped their NDS
    #            branch (and are not in the branchless allowlist)
    def self.coverage
      discovered = discovered_templates
      catalog_templates = PAGES.map(&:template)

      missing = discovered - catalog_templates
      unconverted = catalog_templates.reject do |template|
        BRANCHLESS_NDS_TEMPLATES.include?(template) || branch_template?(template)
      end
      # A cataloged template whose NDS branch has not landed yet (its page PR is
      # still open) is pending, not stale; stale means the template is gone.
      stale, pending = unconverted.partition { |template| !template_exists?(template) }
      covered = catalog_templates - unconverted

      { covered:, pending:, missing:, stale: }
    end

    def self.pending?(page)
      coverage[:pending].include?(page.template)
    end

    # Best-guess GET route path for a template, mapping the Rails-conventional
    # controller/action back to the router. Returns nil when unresolved.
    def self.route_for_template(template)
      controller = File.dirname(template)
      action = File.basename(template)
      route = Rails.application.routes.routes.find do |r|
        defaults = r.defaults
        defaults[:controller] == controller && defaults[:action] == action &&
          r.verb.to_s.include?('GET')
      end
      route&.path&.spec.to_s.delete_suffix('(.:format)').presence
    end

    # The real controller class that renders a template, resolved from the
    # Rails-conventional controller path (template dirname). Returns nil when the
    # constant does not exist (e.g. shared/partial-style templates).
    def self.controller_for_template(template)
      "#{File.dirname(template)}_controller".camelize.constantize
    rescue NameError
      nil
    end

    # Helper-context self-audit. The explorer renders real view templates against
    # its OWN controller, which stubs a fixed set of `helper_method`s so pages
    # render without the full flow. That means a page can reference a helper the
    # explorer stubs while its REAL controller never exposes it to views — the
    # page works in the explorer but 500s in production. This flags exactly that
    # drift: for each catalog page, any explorer-stubbed helper the template
    # references that the page's real controller does not make view-visible.
    #
    # View-visibility is approximated by the controller's `_helpers` module,
    # which aggregates included helper modules plus `helper_method` proxies — the
    # same surface a view resolves against. URL/path helpers (framework-injected,
    # always available in views) are excluded so they do not read as gaps.
    #
    # Returns a hash of template => [missing helper symbols]; empty when wired
    # correctly. Templates whose controller cannot be resolved are skipped (the
    # coverage audit already guards template existence).
    def self.helper_wiring_gaps
      stubbed = NDSPagesController._helper_methods.map(&:to_sym).reject do |helper|
        helper.to_s.end_with?('_path', '_url')
      end.to_set

      PAGES.each_with_object({}) do |page, gaps|
        controller = controller_for_template(page.template)
        next if controller.nil?

        path = Rails.root.join('app/views', "#{page.template}.html.erb")
        next unless path.exist?

        body = path.read
        exposed = controller._helpers.instance_methods.to_set
        referenced = stubbed.select do |helper|
          next false if exposed.include?(helper)

          # Whole-identifier match so `resource` does not match `resource_name`.
          body.match?(/(?<![\w?])#{Regexp.escape(helper.to_s)}(?!\w)/)
        end
        gaps[page.template] = referenced.sort unless referenced.empty?
      end
    end

    Entry = Struct.new(:path, :controller, :action, :template, :page, keyword_init: true)

    # Controller namespaces/mounts that are never user-facing HTML pages.
    NON_PAGE_CONTROLLER_PREFIXES = %w[
      api/ test/ health_check/ rails/ well_known/
    ].freeze

    # Dynamic full-inventory scan. The route table is the single source of
    # truth for the "Legacy universe" of renderable pages; the curated PAGES
    # catalog only supplies render/permutation detail for the NDS ones.
    #
    # Heuristic for "renderable page": a GET route mapping to a controller#action
    # whose Rails-conventional view template (app/views/<controller>/<action>.html.erb)
    # actually exists. This deliberately errs toward precision over recall:
    #   - non-GET, redirects, mounts (Lookbook/sidekiq/mailers), and API/test/
    #     health/rails namespaces are dropped;
    #   - actions that render a non-conventional template (render :other, or a
    #     shared template) are missed — acceptable for a dev audit tool.
    # A page counts as NDS-converted when its template has an `nds_layout?`
    # branch or is in BRANCHLESS_NDS_TEMPLATES.
    def self.inventory
      catalog_by_template = PAGES.index_by(&:template)
      seen = {}

      Rails.application.routes.routes.each do |route|
        defaults = route.defaults
        controller = defaults[:controller]
        action = defaults[:action]
        next if controller.blank? || action.blank?
        next unless route.verb.to_s.include?('GET')
        next if NON_PAGE_CONTROLLER_PREFIXES.any? { |p| controller.start_with?(p) }

        template = "#{controller}/#{action}"
        next unless template_exists?(template)
        next if seen.key?(template)

        seen[template] = Entry.new(
          path: route.path.spec.to_s.delete_suffix('(.:format)'),
          controller:,
          action:,
          template:,
          page: catalog_by_template[template],
        )
      end

      entries = seen.values
      nds, legacy = entries.partition do |entry|
        BRANCHLESS_NDS_TEMPLATES.include?(entry.template) || branch_template?(entry.template)
      end

      # Some NDS pages render a template that does not match their route's
      # controller#action (e.g. Devise sign-in: route controller users/sessions
      # renders devise/sessions/new). The template scan is authoritative for the
      # NDS set, so fold in any discovered NDS template the route walk missed.
      nds_templates = nds.map(&:template)
      discovered_templates.each do |template|
        next if nds_templates.include?(template)

        nds << Entry.new(
          path: route_for_template(template),
          controller: File.dirname(template),
          action: File.basename(template),
          template:,
          page: catalog_by_template[template],
        )
      end

      audit = coverage
      {
        nds: nds.sort_by(&:template),
        legacy: legacy.sort_by(&:template),
        pending: audit[:pending],
        missing: audit[:missing],
        stale: audit[:stale],
      }
    end
  end
end

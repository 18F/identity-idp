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
    # NDS-bucket branch), plus the explicit branchless allowlist above. Scanning
    # templates is preferred over resolving every route's render target because
    # render resolution is unreliable for non-conventional actions.
    def self.discovered_templates
      scanned = Rails.root.glob('app/views/**/*.html.erb').filter_map do |path|
        rel = path.relative_path_from(Rails.root.join('app/views')).to_s
        template = rel.delete_suffix('.html.erb')
        next if File.basename(template).start_with?('_')
        next if template.start_with?('layouts/')
        next unless path.read.include?('nds_layout?')

        template
      end
      (scanned + BRANCHLESS_NDS_TEMPLATES).uniq.sort
    end

    def self.template_exists?(template)
      Rails.root.join('app/views', "#{template}.html.erb").exist?
    end

    def self.branch_template?(template)
      path = Rails.root.join('app/views', "#{template}.html.erb")
      path.exist? && path.read.include?('nds_layout?')
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
      stale = catalog_templates.reject do |template|
        BRANCHLESS_NDS_TEMPLATES.include?(template) || branch_template?(template)
      end
      covered = catalog_templates - stale

      { covered:, missing:, stale: }
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
        missing: audit[:missing],
        stale: audit[:stale],
      }
    end
  end
end

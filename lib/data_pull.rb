# frozen_string_literal: true

require_relative './script_base'

class DataPull
  attr_reader :argv, :stdout, :stderr

  def initialize(argv:, stdout:, stderr:)
    @argv = argv
    @stdout = stdout
    @stderr = stderr
  end

  def script_base
    @script_base ||= ScriptBase.new(
      argv:,
      stdout:,
      stderr:,
      subtask_class: subtask(argv.shift),
      banner: banner,
      reason_arg: false,
    )
  end

  def run
    script_base.run
  end

  def banner
    basename = File.basename($PROGRAM_NAME)
    <<~EOS
      #{basename} [subcommand] [arguments] [options]

      Example usage:

        * #{basename} email-lookup uuid1 uuid2

        * #{basename} events-summary uuid1 uuid2

        * #{basename} ig-request uuid1 uuid2 --requesting-issuer=ABC:DEF:GHI

        * #{basename} mfa-report uuid1 uuid2

        * #{basename} ssn-signature-report ssn1

        * #{basename} profile-summary uuid1 uuid2

        * #{basename} uuid-convert partner-uuid1 partner-uuid2

        * #{basename} uuid-export uuid1 uuid2 --requesting-issuer=ABC:DEF:GHI

        * #{basename} uuid-lookup email1@example.com email2@example.com
      Options:
    EOS
  end

  # @api private
  # A subtask is a class that has a run method, the type signature should look like:
  # +#run(args: Array<String>, config: Config) -> Result+
  # @return [Class,nil]
  def subtask(name)
    {
      'email-lookup' => EmailLookup,
      'events-summary' => EventsSummary,
      'ig-request' => InspectorGeneralRequest,
      'mfa-report' => MfaReport,
      'ssn-signature-report' => SsnSignatureReport,
      'profile-summary' => ProfileSummary,
      'uuid-convert' => UuidConvert,
      'uuid-export' => UuidExport,
      'uuid-lookup' => UuidLookup,
    }[name]
  end

  class UuidLookup
    def run(args:, config:)
      emails = args

      table = []
      table << %w[email uuid]

      uuids = []

      emails.each do |email|
        user = User.find_with_email(email)
        if user
          table << [email, user.uuid]
          uuids << user.uuid
        elsif config.include_missing?
          table << [email, '[NOT FOUND]']
        end
      end

      ScriptBase::Result.new(
        subtask: 'uuid-lookup',
        table:,
        uuids:,
      )
    end
  end

  class UuidConvert
    def run(args:, config:)
      partner_uuids = args

      table = []
      table << %w[partner_uuid source internal_uuid deleted]
      identities = ServiceProviderIdentity
        .includes(:user, :deleted_user, :agency)
        .where(uuid: partner_uuids)
        .order(:uuid)

      identities.each do |identity|
        table << [
          identity.uuid,
          identity.agency.name,
          (identity.user || identity.deleted_user).uuid,
          identity.deleted_user ? true : nil,
        ]
      end

      if config.include_missing?
        (partner_uuids - identities.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', '[NOT FOUND]', nil]
        end
      end

      ScriptBase::Result.new(
        subtask: 'uuid-convert',
        uuids: identities.map { |u| (u.user || u.deleted_user).uuid },
        table:,
      )
    end
  end

  class EmailLookup
    def run(args:, config:)
      uuids = args

      users = User.includes(:email_addresses).where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid email confirmed_at]

      users.each do |user|
        user.email_addresses.sort_by(&:id).each do |email_address|
          table << [user.uuid, email_address.email, email_address.confirmed_at]
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', nil]
        end
      end

      ScriptBase::Result.new(
        subtask: 'email-lookup',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end

  class MfaReport
    def run(args:, config:)
      require 'data_requests/deployed'
      uuids = args

      users, missing_uuids = uuids.map do |uuid|
        DataRequests::Deployed::LookupUserByUuid.new(uuid).call || uuid
      end.partition { |u| u.is_a?(User) }

      output = users.map do |user|
        output = DataRequests::Deployed::CreateMfaConfigurationsReport.new(user).call
        output[:uuid] = user.uuid

        output
      end

      if config.include_missing?
        output += missing_uuids.map do |uuid|
          {
            uuid: uuid,
            phone_configurations: [],
            auth_app_configurations: [],
            webauthn_configurations: [],
            piv_cac_configurations: [],
            backup_code_configurations: [],
            not_found: true,
          }
        end
      end

      ScriptBase::Result.new(
        subtask: 'mfa-report',
        uuids: uuids,
        json: output,
      )
    end
  end

  class SsnSignatureReport
    def run(args:, config:)
      require 'data_requests/deployed'
      ssns = args

      ssn_finders = ssns.map { |ssn| Idv::DuplicateSsnFinder.new(user: nil, ssn: ssn) }
      ssn_signatures = ssn_finders.flat_map do |ssn_finder|
        ssn_finder.ssn_signatures
      end

      profiles = Profile.where(ssn_signature: ssn_signatures).includes(:user)

      table = []
      table << %w[
        uuid
        profile_id
        status
        ssn_signature
        idv_level
        activated_timestamp
        disabled_reason
        gpo_verification_pending_timestamp
        fraud_review_pending_timestamp
        fraud_rejection_timestamp
      ]

      if profiles.any?
        profiles.each do |profile|
          table << [
            profile.user.uuid,
            profile.id,
            profile.active ? 'active' : 'inactive',
            profile.ssn_signature,
            profile.idv_level,
            profile.activated_at,
            profile.deactivation_reason,
            profile.gpo_verification_pending_at,
            profile.fraud_review_pending_at,
            profile.fraud_rejection_at,
          ]
        end
      else
        config.include_missing?
        table << ['[NO PROFILES]', nil, nil, nil, nil, nil, nil, nil, nil, nil]
      end

      ScriptBase::Result.new(
        subtask: 'ssn-signature-report',
        uuids: profiles.map(&:user).map(&:uuid).uniq,
        table:,
      )
    end
  end

  class InspectorGeneralRequest
    def run(args:, config:)
      require 'data_requests/deployed'
      ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
      uuids = args

      if config.depth.nil?
        raise 'Required argument --depth is missing'
      end

      requesting_issuers =
        config.requesting_issuers.presence || compute_requesting_issuers(uuids)

      users, missing_uuids = uuids.map do |uuid|
        DataRequests::Deployed::LookupUserByUuid.new(uuid).call || uuid
      end.partition { |u| u.is_a?(User) }

      shared_device_users =
        if config.depth > 0
          DataRequests::Deployed::LookupSharedDeviceUsers.new(users, config.depth).call
        else
          users
        end

      output = shared_device_users.map do |user|
        DataRequests::Deployed::CreateUserReport.new(user, requesting_issuers).call
      end

      if config.include_missing?
        output += missing_uuids.map do |uuid|
          {
            user_id: nil,
            login_uuid: nil,
            requesting_issuer_uuid: uuid,
            email_addresses: [],
            mfa_configurations: {
              phone_configurations: [],
              auth_app_configurations: [],
              webauthn_configurations: [],
              piv_cac_configurations: [],
              backup_code_configurations: [],
            },
            user_events: [],
            not_found: true,
          }
        end
      end

      ScriptBase::Result.new(
        subtask: 'ig-request',
        uuids: users.map(&:uuid),
        json: output,
      )
    end

    private

    def compute_requesting_issuers(uuids)
      service_providers = ServiceProviderIdentity.where(uuid: uuids).pluck(:service_provider)
      return nil if service_providers.empty?
      service_provider, _count = service_providers.tally.max_by { |_sp, count| count }

      if service_providers.count > 1
        warn "Multiple computed service providers: #{service_providers.join(', ')}"
      end

      warn "Computed service provider #{service_provider}"

      Array(service_provider)
    end
  end

  class ProfileSummary
    def run(args:, config:)
      uuids = args

      users = User.includes(:profiles).where(uuid: uuids).order(:uuid)

      table = []
      table << %w[
        uuid
        profile_id
        status
        idv_level
        activated_timestamp
        disabled_reason
        gpo_verification_pending_timestamp
        fraud_review_pending_timestamp
        fraud_rejection_timestamp
      ]

      users.each do |user|
        if user.profiles.any?
          user.profiles.sort_by(&:id).each do |profile|
            table << [
              user.uuid,
              profile.id,
              profile.active ? 'active' : 'inactive',
              profile.idv_level,
              profile.activated_at,
              profile.deactivation_reason,
              profile.gpo_verification_pending_at,
              profile.fraud_review_pending_at,
              profile.fraud_rejection_at,
            ]
          end
        elsif config.include_missing?
          table << [user.uuid, '[HAS NO PROFILE]', nil, nil, nil, nil, nil, nil, nil]
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[UUID NOT FOUND]', nil, nil, nil, nil, nil, nil, nil]
        end
      end

      ScriptBase::Result.new(
        subtask: 'profile-summary',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end

  class UuidExport
    def run(args:, config:)
      login_uuids = args

      uuids = []
      table = []
      table << %w[login_uuid agency issuer external_uuid]

      User.includes(:agency_identities, identities: { service_provider_record: :agency })
        .where(uuid: login_uuids)
        .then do |scope|
          if config.requesting_issuers.present?
            scope.where(service_provider_record: { issuer: config.requesting_issuers })
          else
            scope
          end
        end.each do |user|
          user.identities.each do |identity|
            uuids << user.uuid
            external_uuid = user.agency_identities&.find do |a_i|
                              a_i.agency == identity.service_provider_record.agency
                            end&.uuid || identity.uuid
            table << [
              user.uuid,
              identity.service_provider_record.agency&.name,
              identity.service_provider_record.issuer,
              external_uuid,
            ]
          end
        end

      if config.include_missing?
        (login_uuids - uuids.uniq).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', '[NOT FOUND]', '[NOT FOUND]']
        end
      end

      ScriptBase::Result.new(
        subtask: 'uuid-export',
        uuids: uuids.uniq,
        table:,
      )
    end
  end

  class EventsSummary
    def run(args:, config:)
      uuids = args

      sql = <<-SQL
        SELECT
          users.uuid AS uuid
        , events.created_at::date AS date
        , COUNT(events.id) AS events_count
        FROM users
        JOIN events ON users.id = events.user_id
        WHERE users.uuid IN (:uuids)
        GROUP BY
          users.uuid
        , events.created_at::date
        ORDER BY
          users.uuid ASC
        , events.created_at::date DESC
      SQL

      results = ActiveRecord::Base.connection.execute(
        ApplicationRecord.sanitize_sql_array([sql, { uuids: uuids }]),
      )

      table = []
      table << %w[uuid date events_count]

      results.each do |row|
        table << [row['uuid'], row['date'], row['events_count']]
      end

      found_uuids = results.map { |r| r['uuid'] }.uniq

      if config.include_missing?
        (uuids - found_uuids).each do |missing_uuid|
          table << [missing_uuid, '[UUID NOT FOUND]', nil]
        end
      end

      ScriptBase::Result.new(
        subtask: 'events-summary',
        uuids: found_uuids,
        table:,
      )
    end
  end
end

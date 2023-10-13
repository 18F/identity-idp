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

        * #{basename} ig-request uuid1 uuid2 --requesting-issuer ABC:DEF:GHI

        * #{basename} profile-summary uuid1 uuid2

        * #{basename} uuid-convert partner-uuid1 partner-uuid2

        * #{basename} uuid-export uuid1 uuid2 --requesting-issuer ABC:DEF:GHI

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
      table << %w[partner_uuid source internal_uuid]
      identities = AgencyIdentity.includes(:user, :agency).where(uuid: partner_uuids).order(:uuid)

      identities.each do |identity|
        table << [identity.uuid, identity.agency.name, identity.user.uuid]
      end

      if config.include_missing?
        (partner_uuids - identities.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[NOT FOUND]', '[NOT FOUND]']
        end
      end

      ScriptBase::Result.new(
        subtask: 'uuid-convert',
        uuids: identities.map { |u| u.user.uuid },
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

  class InspectorGeneralRequest
    def run(args:, config:)
      require 'data_requests/deployed'
      ActiveRecord::Base.connection.execute('SET statement_timeout = 0')
      uuids = args

      users = uuids.map { |uuid| DataRequests::Deployed::LookupUserByUuid.new(uuid).call }.compact
      shared_device_users = DataRequests::Deployed::LookupSharedDeviceUsers.new(users).call

      output = shared_device_users.map do |user|
        DataRequests::Deployed::CreateUserReport.new(user, config.requesting_issuers).call
      end

      ScriptBase::Result.new(
        subtask: 'ig-request',
        uuids: users.map(&:uuid),
        json: output,
      )
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
              profile.activated_at,
              profile.deactivation_reason,
              profile.gpo_verification_pending_at,
              profile.fraud_review_pending_at,
              profile.fraud_rejection_at,
            ]
          end
        elsif config.include_missing?
          table << [user.uuid, '[HAS NO PROFILE]', nil, nil, nil, nil, nil, nil]
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[UUID NOT FOUND]', nil, nil, nil, nil, nil, nil]
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

      User.includes(:agency_identities, identities: { service_provider_record: :agency }).
        where(uuid: login_uuids).
        then do |scope|
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

      users = User.includes(events: :device).where(uuid: uuids).order(:uuid)

      table = []
      table << %w[uuid event_type event_timestamp event_ip device_cookie]

      users.each do |user|
        user.events.sort_by(&:created_at).each do |event|
          table << [
            user.uuid,
            event.event_type,
            event.created_at,
            event.ip,
            event.device&.cookie_uuid,
          ]
        end
      end

      if config.include_missing?
        (uuids - users.map(&:uuid)).each do |missing_uuid|
          table << [missing_uuid, '[UUID NOT FOUND]', nil, nil, nil]
        end
      end

      ScriptBase::Result.new(
        subtask: 'events-summary',
        uuids: users.map(&:uuid),
        table:,
      )
    end
  end
end

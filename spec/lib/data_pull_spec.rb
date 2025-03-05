require 'rails_helper'
require 'tableparser'
require 'data_pull'

RSpec.describe DataPull do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:argv) { [] }

  subject(:data_pull) { DataPull.new(argv:, stdout:, stderr:) }

  describe 'command line flags' do
    let(:argv) { ['uuid-lookup', user.email_addresses.first.email] }
    let(:user) { create(:user) }

    describe '--help' do
      before { argv << '--help' }
      it 'prints a help message' do
        data_pull.run

        expect(stdout.string).to include('Options:')
      end

      it 'prints help to stderr', aggregate_failures: true do
        data_pull.run

        expect(stderr.string).to include('*Task*: `help`')
        expect(stderr.string).to include('*UUIDs*: N/A')
      end
    end

    describe '--csv' do
      before { argv << '--csv' }
      it 'formats output as CSV' do
        data_pull.run

        expect(CSV.parse(stdout.string)).to eq(
          [
            ['email', 'uuid'],
            [user.email_addresses.first.email, user.uuid],
          ],
        )
      end
    end

    describe '--table' do
      before { argv << '--table' }
      it 'formats output as an ASCII table' do
        data_pull.run

        expect(Tableparser.parse(stdout.string)).to eq(
          [
            ['email', 'uuid'],
            [user.email_addresses.first.email, user.uuid],
          ],
        )
      end
    end

    it 'logs UUIDs and the command name to STDERR formatted for Slack', aggregate_failures: true do
      data_pull.run

      expect(stderr.string).to include('`uuid-lookup`')
      expect(stderr.string).to include("`#{user.uuid}`")
    end

    describe '--json' do
      before { argv << '--json' }
      it 'formats output as JSON' do
        data_pull.run

        expect(JSON.parse(stdout.string)).to eq(
          [
            {
              'email' => user.email_addresses.first.email,
              'uuid' => user.uuid,
            },
          ],
        )
      end
    end

    describe '--include-missing' do
      let(:argv) { ['uuid-lookup', 'does_not_exist@example.com', '--include-missing', '--json'] }
      it 'adds rows for missing values' do
        data_pull.run

        expect(JSON.parse(stdout.string)).to eq(
          [
            {
              'email' => 'does_not_exist@example.com',
              'uuid' => '[NOT FOUND]',
            },
          ],
        )
      end
    end

    describe '--no-include-missing' do
      let(:argv) { ['uuid-lookup', 'does_not_exist@example.com', '--no-include-missing', '--json'] }
      it 'does not add rows for missing values' do
        data_pull.run

        expect(JSON.parse(stdout.string)).to be_empty
      end
    end

    describe 'ig-query task' do
      let(:service_provider) { create(:service_provider) }
      let(:identity) { IdentityLinker.new(user, service_provider).link_identity }

      let(:argv) do
        ['ig-request', identity.uuid, '--requesting-issuer', service_provider.issuer]
      end

      it 'runs the data requests report and prints it as JSON' do
        data_pull.run

        response = JSON.parse(stdout.string, symbolize_names: true)
        expect(response.first.keys).to contain_exactly(
          :user_id,
          :login_uuid,
          :requesting_issuer_uuid,
          :email_addresses,
          :mfa_configurations,
          :user_events,
        )
      end

      context 'with a UUID that is not found' do
        let(:uuid) { 'abcdef' }
        let(:argv) do
          ['ig-request', uuid, '--requesting-issuer', service_provider.issuer]
        end

        it 'returns an empty hash for that user' do
          data_pull.run

          response = JSON.parse(stdout.string, symbolize_names: true)
          expect(response.first).to eq(
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
          )
        end
      end
    end
  end

  describe DataPull::UuidLookup do
    subject(:subtask) { DataPull::UuidLookup.new }

    describe '#run' do
      let(:users) { create_list(:user, 2) }

      let(:args) { [*users.map { |u| u.email_addresses.first.email }, 'missing@example.com'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }

      subject(:result) { subtask.run(args:, config:) }

      it 'looks up the UUIDs for the given email addresses', aggregate_failures: true do
        expected_table = [
          ['email', 'uuid'],
          *users.map { |u| [u.email_addresses.first.email, u.uuid] },
          ['missing@example.com', '[NOT FOUND]'],
        ]

        expect(result.table).to eq(expected_table)
        expect_consistent_row_length(result.table)
        expect(result.subtask).to eq('uuid-lookup')
        expect(result.uuids).to match_array(users.map(&:uuid))
      end
    end
  end

  describe DataPull::UuidConvert do
    subject(:subtask) { DataPull::UuidConvert.new }

    describe '#run' do
      let(:service_providers) { create_list(:service_provider, 2) }
      let(:users) { create_list(:user, 2) }
      let(:external_uuids) do
        users.zip(service_providers).map do |user, service_provider|
          IdentityLinker.new(user, service_provider).link_identity.uuid
        end.sort
      end

      let(:args) { [*external_uuids, 'does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'converts the agency agency identities to internal UUIDs', aggregate_failures: true do
        expect(result.table).to eq(
          [
            ['partner_uuid', 'source', 'internal_uuid', 'deleted'],
            *external_uuids.map do |external_uuid|
              identity = AgencyIdentity.find_by(uuid: external_uuid)

              [
                identity.uuid,
                identity.agency.name,
                identity.user.uuid,
                nil,
              ]
            end,
            ['does-not-exist', '[NOT FOUND]', '[NOT FOUND]', nil],
          ],
        )

        expect(result.subtask).to eq('uuid-convert')
        expect(result.uuids).to match_array(users.map(&:uuid))
      end

      context 'when users have been deleted' do
        before do
          user = AgencyIdentity.find_by(uuid: external_uuids.last).user
          DeletedUser.create_from_user(user)
          user.destroy
        end

        it 'still includes them and marks them as deleted' do
          expected_table = [
            ['partner_uuid', 'source', 'internal_uuid', 'deleted'],
            external_uuids.first.then do |external_uuid|
              identity = AgencyIdentity.find_by(uuid: external_uuid)

              [
                identity.uuid,
                identity.agency.name,
                identity.user.uuid,
                nil,
              ]
            end,
            external_uuids.last.then do |external_uuid|
              identity = ServiceProviderIdentity.find_by(uuid: external_uuid)

              [
                identity.uuid,
                identity.agency.name,
                DeletedUser.find_by(user_id: identity.user_id).uuid,
                true,
              ]
            end,
            ['does-not-exist', '[NOT FOUND]', '[NOT FOUND]', nil],
          ]
          expect(result.table).to eq(expected_table)

          expect(result.subtask).to eq('uuid-convert')
          expect_consistent_row_length(result.table)
          expect(result.uuids).to match_array(users.map(&:uuid))
        end
      end
    end
  end

  describe DataPull::EmailLookup do
    subject(:subtask) { DataPull::EmailLookup.new }

    describe '#run' do
      let(:user) { create(:user, :with_multiple_emails) }

      let(:args) { [user.uuid, 'does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'loads email addresses for the user', aggregate_failures: true do
        expected_table = [
          ['uuid', 'email', 'confirmed_at'],
          *user.email_addresses.sort_by(&:id).map do |e|
            [e.user.uuid, e.email, kind_of(Time)]
          end,
          ['does-not-exist', '[NOT FOUND]', nil],
        ]
        expect(result.table).to match(expected_table)
        expect(result.subtask).to eq('email-lookup')
        expect_consistent_row_length(result.table)
        expect(result.uuids).to eq([user.uuid])
      end
    end
  end

  describe DataPull::MfaReport do
    subject(:subtask) { DataPull::MfaReport.new }

    describe '#run' do
      let(:user) { create(:user) }
      let(:args) { [user.uuid] }
      let(:config) { ScriptBase::Config.new }

      subject(:result) { subtask.run(args:, config:) }

      it 'runs the MFA report, has a JSON-only response', aggregate_failures: true do
        expect(result.table).to be_nil
        expect(result.json.first.keys).to contain_exactly(
          :uuid,
          :phone_configurations,
          :auth_app_configurations,
          :webauthn_configurations,
          :piv_cac_configurations,
          :backup_code_configurations,
        )

        expect(result.subtask).to eq('mfa-report')
        expect(result.uuids).to eq([user.uuid])
      end
    end
  end

  describe DataPull::InspectorGeneralRequest do
    subject(:subtask) { DataPull::InspectorGeneralRequest.new }

    describe '#run' do
      let(:user) { create(:user) }
      let(:service_provider) { create(:service_provider) }
      let(:identity) { IdentityLinker.new(user, service_provider).link_identity }
      let(:args) { [user.uuid] }
      let(:config) { ScriptBase::Config.new(requesting_issuers: [service_provider.issuer]) }

      subject(:result) { subtask.run(args:, config:) }

      it 'runs the create users report, has a JSON-only response', aggregate_failures: true do
        expect(result.table).to be_nil
        expect(result.json.first.keys).to contain_exactly(
          :user_id,
          :login_uuid,
          :requesting_issuer_uuid,
          :email_addresses,
          :mfa_configurations,
          :user_events,
        )

        expect(result.subtask).to eq('ig-request')
        expect(result.uuids).to eq([user.uuid])
      end

      context 'with SP UUID argument and no requesting issuer' do
        let(:args) { [identity.uuid] }
        let(:config) { ScriptBase::Config.new }

        it 'runs the report with computed requesting issuer', aggregate_failures: true do
          expect(result.table).to be_nil
          expect(result.json.first.keys).to contain_exactly(
            :user_id,
            :login_uuid,
            :requesting_issuer_uuid,
            :email_addresses,
            :mfa_configurations,
            :user_events,
          )

          expect(result.subtask).to eq('ig-request')
          expect(result.uuids).to eq([user.uuid])
        end
      end
    end
  end

  describe DataPull::ProfileSummary do
    subject(:subtask) { DataPull::ProfileSummary.new }

    describe '#run' do
      let(:user) { create(:profile, :active, :verified).user }
      let(:user_without_profile) { create(:user) }

      let(:args) { [user.uuid, user_without_profile.uuid, 'uuid-does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'loads profile summary for the user', aggregate_failures: true do
        expected_result = [
          ['uuid', 'profile_id', 'status', 'idv_level', 'activated_timestamp', 'disabled_reason',
           'gpo_verification_pending_timestamp', 'fraud_review_pending_timestamp',
           'fraud_rejection_timestamp'],
          *user.profiles.sort_by(&:id).map do |p|
            profile_status = p.active ? 'active' : 'inactive'
            [
              user.uuid,
              p.id,
              profile_status,
              p.idv_level,
              kind_of(Time),
              p.deactivation_reason,
              nil,
              nil,
              nil,
            ]
          end,
          [user_without_profile.uuid, '[HAS NO PROFILE]', nil, nil, nil, nil, nil, nil, nil],
          ['uuid-does-not-exist', '[UUID NOT FOUND]', nil, nil, nil, nil, nil, nil, nil],
        ]
        expect(result.table).to match_array(expected_result)
        expect_consistent_row_length(result.table)

        expect(result.subtask).to eq('profile-summary')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])
      end
    end
  end

  describe DataPull::UuidExport do
    subject(:subtask) { DataPull::UuidExport.new }

    let(:user1) { create(:user, :fully_registered) }
    let(:user2) { create(:user, :fully_registered) }

    let(:agency) { create(:agency) }
    let(:service_provider) { create(:service_provider, agency_id: agency.id) }
    let(:other_sp) { create(:service_provider, active: true, agency_id: agency.id) }

    let(:identity) do
      create(:service_provider_identity, service_provider: service_provider.issuer, user: user1)
    end
    let(:other_identity) do
      create(:service_provider_identity, service_provider: other_sp.issuer, user: user2)
    end

    let(:agency_identity) do
      create(:agency_identity, agency: agency, user: user1, uuid: identity.uuid)
    end
    let(:other_agency_identity) do
      create(:agency_identity, agency: agency, user: user2, uuid: other_identity.uuid)
    end

    let(:args) { [user1.uuid, user2.uuid, 'does-not-exist'] }
    let(:include_missing) { true }
    subject(:result) { subtask.run(args: args, config: config) }

    describe '#run' do
      context 'without requesting issuers' do
        let(:config) { ScriptBase::Config.new(include_missing: include_missing) }

        it 'return partner UUIDs for all apps', aggregate_failures: true do
          expected_table = [
            ['login_uuid', 'agency', 'issuer', 'external_uuid'],
            [user1.uuid, agency.name, service_provider.issuer, agency_identity.uuid],
            [user2.uuid, agency.name, other_sp.issuer, other_agency_identity.uuid],
            ['does-not-exist', '[NOT FOUND]', '[NOT FOUND]', '[NOT FOUND]'],
          ]

          expect(result.table).to match_array(expected_table)
          expect_consistent_row_length(result.table)
          expect(result.subtask).to eq('uuid-export')
          expect(result.uuids).to match_array([user1.uuid, user2.uuid])
        end
      end

      context 'with requesting issuers' do
        let(:config) do
          ScriptBase::Config.new(
            include_missing: include_missing,
            requesting_issuers: [service_provider.issuer],
          )
        end

        it 'return partner UUIDs for just provided app', aggregate_failures: true do
          expected_table = [
            ['login_uuid', 'agency', 'issuer', 'external_uuid'],
            [user1.uuid, agency.name, service_provider.issuer, agency_identity.uuid],
            [user2.uuid, '[NOT FOUND]', '[NOT FOUND]', '[NOT FOUND]'],
            ['does-not-exist', '[NOT FOUND]', '[NOT FOUND]', '[NOT FOUND]'],
          ]

          expect(result.table).to match_array(expected_table)
          expect(result.subtask).to eq('uuid-export')
          expect(result.uuids).to match_array([user1.uuid])
        end
      end
    end
  end

  describe DataPull::EventsSummary do
    subject(:subtask) { DataPull::EventsSummary.new }

    let(:user) { create(:user) }

    before do
      create(
        :event,
        user: user,
        event_type: :account_created,
        ip: '1.2.3.4',
        created_at: Date.new(2023, 1, 1).in_time_zone('UTC'),
      )

      create_list(
        :event,
        5,
        user: user,
        event_type: :account_created,
        ip: '1.2.3.4',
        created_at: Date.new(2023, 1, 2).in_time_zone('UTC'),
      )
    end

    let(:args) { [user.uuid, 'uuid-does-not-exist'] }
    let(:config) { ScriptBase::Config.new(include_missing: true) }
    subject(:result) { subtask.run(args:, config:) }

    describe '#run' do
      it 'loads events for the users' do
        expected_table = [
          %w[uuid date events_count],
          [user.uuid, Date.new(2023, 1, 2), 5],
          [user.uuid, Date.new(2023, 1, 1), 1],
          ['uuid-does-not-exist', '[UUID NOT FOUND]', nil],
        ]
        expect(result.table).to match_array(expected_table)
        expect(result.subtask).to eq('events-summary')
        expect_consistent_row_length(result.table)
        expect(result.uuids).to match_array([user.uuid])
      end
    end
  end

  # Assert that each row has the same length
  def expect_consistent_row_length(table)
    first_row_length = table.first.length

    expect(table.all? { |row| row.length == first_row_length }).to eq(true)
  end
end

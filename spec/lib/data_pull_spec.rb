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
        expect(result.table).to eq(
          [
            ['email', 'uuid'],
            *users.map { |u| [u.email_addresses.first.email, u.uuid] },
            ['missing@example.com', '[NOT FOUND]'],
          ],
        )

        expect(result.subtask).to eq('uuid-lookup')
        expect(result.uuids).to match_array(users.map(&:uuid))
      end
    end
  end

  describe DataPull::UuidConvert do
    subject(:subtask) { DataPull::UuidConvert.new }

    describe '#run' do
      let(:agency_identities) { create_list(:agency_identity, 2).sort_by(&:uuid) }

      let(:args) { [*agency_identities.map(&:uuid), 'does-not-exist'] }
      let(:include_missing) { true }
      let(:config) { ScriptBase::Config.new(include_missing:) }
      subject(:result) { subtask.run(args:, config:) }

      it 'converts the agency agency identities to internal UUIDs', aggregate_failures: true do
        expect(result.table).to eq(
          [
            ['partner_uuid', 'source', 'internal_uuid'],
            *agency_identities.map { |a| [a.uuid, a.agency.name, a.user.uuid] },
            ['does-not-exist', '[NOT FOUND]', '[NOT FOUND]'],
          ],
        )

        expect(result.subtask).to eq('uuid-convert')
        expect(result.uuids).to match_array(agency_identities.map(&:user).map(&:uuid))
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
        expect(result.table).to match(
          [
            ['uuid', 'email', 'confirmed_at'],
            *user.email_addresses.sort_by(&:id).map do |e|
              [e.user.uuid, e.email, kind_of(Time)]
            end,
            ['does-not-exist', '[NOT FOUND]', nil],
          ],
        )

        expect(result.subtask).to eq('email-lookup')
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
        expect(result.table).to match_array(
          [
            ['uuid', 'profile_id', 'status', 'activated_timestamp', 'disabled_reason',
             'gpo_verification_pending_timestamp', 'fraud_review_pending_timestamp',
             'fraud_rejection_timestamp'],
            *user.profiles.sort_by(&:id).map do |p|
              profile_status = p.active ? 'active' : 'inactive'
              [user.uuid, p.id, profile_status, kind_of(Time), p.deactivation_reason, nil, nil, nil]
            end,
            [user_without_profile.uuid, '[HAS NO PROFILE]', nil, nil, nil, nil, nil, nil],
            ['uuid-does-not-exist', '[UUID NOT FOUND]', nil, nil, nil, nil, nil, nil],
          ],
        )

        expect(result.subtask).to eq('profile-summary')
        expect(result.uuids).to match_array([user.uuid, user_without_profile.uuid])
      end
    end
  end
end

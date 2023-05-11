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
  end

  describe DataPull::UuidLookup do
    subject(:subtask) { DataPull::UuidLookup.new }

    describe '#run' do
      let(:users) { create_list(:user, 2) }

      let(:args) { [*users.map { |u| u.email_addresses.first.email }, 'missing@example.com'] }
      let(:include_missing) { true }

      subject(:result) { subtask.run(args:, include_missing:) }

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
      subject(:result) { subtask.run(args:, include_missing:) }

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
      subject(:result) { subtask.run(args:, include_missing:) }

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
end

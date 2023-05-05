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
      let(:include_missing) { true }
    end
  end

  describe DataPull::UuidConvert do
    subject(:subtask) { DataPull::UuidConvert.new }

    describe '#run' do
      let(:include_missing) { true }
    end
  end

  describe DataPull::EmailLookup do
    subject(:subtask) { DataPull::EmailLookup.new }

    describe '#run' do
      let(:include_missing) { true }
    end
  end

  describe DataPull::ProfileStatus do
    subject(:subtask) { DataPull::ProfileStatus.new }

    describe '#run' do
    end
  end
end

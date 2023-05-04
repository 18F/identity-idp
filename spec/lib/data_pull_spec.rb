require 'rails_helper'

RSpec.describe DataPull do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:argv) { [] }

  subject(:data_pull) { DataPull.new(argv:, stdout:, stderr:) }

  describe 'command line flags' do
    describe '--help' do
    end

    describe '--csv' do
    end

    describe '--table' do
    end

    describe '--include-missing' do
    end

    describe '--no-include-missing' do
    end
  end


  describe DataPull::UuidLookup do
    subject(:subtask) { DataPull::UuidLookup.new }

    describe '#run' do
    end
  end

  describe DataPull::UuidConvert do
    subject(:subtask) { DataPull::UuidConvert.new }

    describe '#run' do
    end
  end

  describe DataPull::EmailLookup do
    subject(:subtask) { DataPull::EmailLookup.new }

    describe '#run' do
    end
  end

  describe DataPull::ProfileStatus do
    subject(:subtask) { DataPull::ProfileStatus.new }

    describe '#run' do
    end
  end
end

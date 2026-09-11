require 'rails_helper'

RSpec.describe SeedRunner do
  subject(:seed_runner) { SeedRunner.new(logger: logger) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }

  describe '#run' do
    it 'logs a start and success message when the block succeeds' do
      seed_runner.run('SomeSeeder') { 'noop' }

      expect(logger).to have_received(:info).with('[db:seed] Starting SomeSeeder')
      expect(logger).to have_received(:info).with(/\[db:seed\] SomeSeeder succeeded \(\d+\.\d+s\)/)
    end

    it 'logs a failure message and does not raise when the block raises' do
      expect do
        seed_runner.run('SomeSeeder') { raise ArgumentError, 'bad config' }
      end.to_not raise_error

      expect(logger).to have_received(:error).with(
        '[db:seed] SomeSeeder failed: ArgumentError: bad config',
      )
    end

    it 'runs subsequent seeders after a prior one fails' do
      seed_runner.run('FailingSeeder') { raise 'boom' }
      ran = false
      seed_runner.run('NextSeeder') { ran = true }

      expect(ran).to eq(true)
    end
  end

  describe '#finish!' do
    context 'when no seeders failed' do
      it 'logs a success summary and does not raise' do
        seed_runner.run('SomeSeeder') { 'noop' }

        expect { seed_runner.finish! }.to_not raise_error
        expect(logger).to have_received(:info).with(
          '[db:seed] Seeding completed: all seeders succeeded',
        )
      end
    end

    context 'when one or more seeders failed' do
      it 'logs a failure summary and raises' do
        seed_runner.run('FailingSeeder') { raise 'boom' }

        expect { seed_runner.finish! }.to raise_error('db:seed failed for: FailingSeeder')
        expect(logger).to have_received(:error).with(
          '[db:seed] Seeding completed with failures: FailingSeeder',
        )
      end

      it 'includes every failed seeder by name' do
        seed_runner.run('FirstFailure') { raise 'boom' }
        seed_runner.run('SecondFailure') { raise 'boom' }

        expect { seed_runner.finish! }.to raise_error(
          'db:seed failed for: FirstFailure, SecondFailure',
        )
      end
    end
  end
end

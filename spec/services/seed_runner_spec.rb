require 'rails_helper'

RSpec.describe SeedRunner do
  subject(:seed_runner) { SeedRunner.new(logger: logger) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }

  before do
    stub_const('FakeSeeder', Class.new { def run; end })
    stub_const('AnotherFakeSeeder', Class.new { def run; end })
  end

  describe '#run' do
    it 'logs a start and success message using the seeder class name by default' do
      seed_runner.run(FakeSeeder.new, &:run)

      expect(logger).to have_received(:info).with('[db:seed] Starting FakeSeeder')
      expect(logger).to have_received(:info).with(/\[db:seed\] FakeSeeder succeeded \(\d+\.\d+s\)/)
    end

    it 'uses the given name instead of the seeder class name when provided' do
      seed_runner.run(FakeSeeder.new, name: 'FakeSeeder#special') { |seeder| seeder.run }

      expect(logger).to have_received(:info).with('[db:seed] Starting FakeSeeder#special')
    end

    it 'logs a failure message and does not raise when the block raises' do
      expect do
        seed_runner.run(FakeSeeder.new) { raise ArgumentError, 'bad config' }
      end.to_not raise_error

      expect(logger).to have_received(:error).with(
        '[db:seed] FakeSeeder failed: ArgumentError: bad config',
      )
    end

    it 'runs subsequent seeders after a prior one fails' do
      seed_runner.run(FakeSeeder.new) { raise 'boom' }
      ran = false
      seed_runner.run(AnotherFakeSeeder.new) { ran = true }

      expect(ran).to eq(true)
    end
  end

  describe '#finish!' do
    context 'when no seeders failed' do
      it 'logs a success summary and does not raise' do
        seed_runner.run(FakeSeeder.new, &:run)

        expect { seed_runner.finish! }.to_not raise_error
        expect(logger).to have_received(:info).with(
          '[db:seed] Seeding completed: all seeders succeeded',
        )
      end
    end

    context 'when one or more seeders failed' do
      it 'logs a failure summary and raises' do
        seed_runner.run(FakeSeeder.new) { raise 'boom' }

        expect { seed_runner.finish! }.to raise_error('db:seed failed for: FakeSeeder')
        expect(logger).to have_received(:error).with(
          '[db:seed] Seeding completed with failures: FakeSeeder',
        )
      end

      it 'includes every failed seeder by name' do
        seed_runner.run(FakeSeeder.new) { raise 'boom' }
        seed_runner.run(AnotherFakeSeeder.new) { raise 'boom' }

        expect { seed_runner.finish! }.to raise_error(
          'db:seed failed for: FakeSeeder, AnotherFakeSeeder',
        )
      end
    end
  end
end

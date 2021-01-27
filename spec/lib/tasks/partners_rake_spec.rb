require 'rails_helper'
require 'rake'

describe 'partners rake tasks' do
  before do
    Rake.application.rake_require 'tasks/partners'
    Rake::Task.define_task(:environment)
  end

  describe 'partners:seed_users' do
    let(:task) { 'partners:seed_users' }
    let!(:prev_csv_file) { ENV['CSV_FILE'] }
    let!(:prev_email_domain) { ENV['EMAIL_DOMAIN'] }

    around do |ex|
      ex.run
    rescue SystemExit
    end

    after do
      ENV['CSV_FILE'] = prev_csv_file
      ENV['EMAIL_DOMAIN'] = prev_email_domain
      Rake.application[task].reenable
    end

    context 'with missing CSV_FILE' do
      before do
        ENV.delete('CSV_FILE')
        ENV['EMAIL_DOMAIN'] = 'foo.com'
      end

      it 'displays an error message' do
        expect { Rake::Task[task].invoke }.to \
          output("You must define the environment variables CSV_FILE and EMAIL_DOMAIN\n").to_stdout
      end

      it 'exits' do
        allow($stdout).to receive(:puts) # suppress output
        expect { Rake::Task[task].invoke }.to raise_error(SystemExit)
      end
    end

    context 'with missing EMAIL_DOMAIN' do
      before do
        ENV['CSV_FILE'] = 'foo.csv'
        ENV.delete('EMAIL_DOMAIN')
      end

      it 'displays an error message' do
        expect { Rake::Task[task].invoke }.to \
          output("You must define the environment variables CSV_FILE and EMAIL_DOMAIN\n").to_stdout
      end

      it 'exits' do
        allow($stdout).to receive(:puts) # suppress output
        expect { Rake::Task[task].invoke }.to raise_error(SystemExit)
      end
    end

    context 'with both ENV variables' do
      before do
        ENV['CSV_FILE'] = 'spec/fixtures/valid_user_csv.csv'
        ENV['EMAIL_DOMAIN'] = 'foo.com'
      end

      it 'works with valid input' do
        expect { Rake::Task[task].invoke }.to \
          output("2 users created\nComplete!\n").to_stdout

        # clean up
        output_file = ENV['CSV_FILE'].gsub('.csv', '-updated.csv')
        File.delete(output_file)
      end

      it 'displays a helpful error message with errors' do
        allow(UserSeeder).to receive(:run).and_raise(ArgumentError.new('foo'))

        expect { Rake::Task[task].invoke }.to output("ERROR: foo\n").to_stdout
      end

      it 'exits with errors' do
        allow($stdout).to receive(:puts) # suppress output
        allow(UserSeeder).to receive(:run).and_raise(ArgumentError.new('foo'))

        expect { Rake::Task[task].invoke }.to raise_error(SystemExit)
      end
    end
  end
end

require 'rails_helper'

RSpec.describe AgencySeeder do
  subject(:instance) { AgencySeeder.new(rails_env: rails_env, deploy_env: deploy_env) }
  let(:rails_env) { 'test' }
  let(:deploy_env) { 'int' }

  describe '#run' do
    before { Agency.delete_all }

    subject(:run) { instance.run }

    it 'inserts agencies into the database from agencies.yml' do
      expect { run }.to change(Agency, :count)
    end

    it 'inserts agencies in the proper order from agencies.yml' do
      run
      expect(Agency.find_by(id: 1).name).to eq('DHS')
      expect(Agency.find_by(id: 2).name).to eq('OPM')
      expect(Agency.find_by(id: 3).name).to eq('USDS')
    end

    context 'when an agency already exists in the database' do
      before do
        Agency.create(id: 1, name: 'FOO')
      end

      it 'updates the attributes based on the current value of the yml file' do
        expect(Agency.find_by(id: 1).name).to eq('FOO')
        run
        expect(Agency.find_by(id: 1).name).to eq('DHS')
      end
    end

    context 'when agencies.yml has a remote setting' do
      before do
        location = 'https://raw.githubusercontent.com/18F/identity-idp/master/config/agencies.yml'
        RemoteSetting.create(
          name: 'agencies.yml', url: location, contents: "test:\n  1:\n    name: 'CBP'",
        )
      end

      it 'updates the attributes based on the current value of the yml file' do
        Agency.create(id: 1, name: 'FOO')
        expect(Agency.find_by(id: 1).name).to eq('FOO')
        run
        expect(Agency.find_by(id: 1).name).to eq('CBP')
      end

      it 'insert the attributes based on the contents of the remote setting' do
        run
        expect(Agency.find_by(id: 1).name).to eq('CBP')
        expect(Agency.count).to eq(1)
      end
    end
  end
end

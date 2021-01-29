require 'rails_helper'

RSpec.describe AgencySeeder do
  subject(:instance) do
    AgencySeeder.new(
      rails_env: rails_env,
      deploy_env: deploy_env,
      yaml_path: 'spec/fixtures',
    )
  end
  let(:rails_env) { 'test' }
  let(:deploy_env) { 'int' }

  describe '#run' do
    before { Agency.delete_all }

    subject(:run) { instance.run }

    # This implictly validates that the `abbreviation` attribute in the YAML is
    # ignored
    it 'inserts agencies into the database from agencies.yml' do
      expect { run }.to change(Agency, :count)
    end

    it 'inserts agencies in the proper order from agencies.yml' do
      run
      expect(Agency.find_by(id: 1).name).to eq('DHS')
      expect(Agency.find_by(id: 2).name).to eq('OPM')
      expect(Agency.find_by(id: 3).name).to eq('EOP')
    end

    it 'updates existing agencies based on the current value of the yml file' do
      Agency.create(id: 1, name: 'FOO')

      expect(Agency.find_by(id: 1).name).to eq('FOO')
      run
      expect(Agency.find_by(id: 1).name).to eq('DHS')
    end
  end
end

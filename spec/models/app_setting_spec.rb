describe AppSetting do
  subject { build(:app_setting) }

  it { is_expected.to validate_uniqueness_of(:name) }
  it { is_expected.to validate_presence_of(:name) }

  it { is_expected.to allow_value('Some Setting').for(:name) }
  it { is_expected.to allow_value('Some Value').for(:value) }

  shared_examples_for 'Boolean App Setting' do
    it do
      is_expected.to_not allow_value('foo').for(:value).with_message(
        t('activerecord.errors.models.app_setting.attributes.value.invalid')
      )
    end

    it { is_expected.to allow_value('0', '1').for(:value) }
  end

  context 'when name is RegistrationsEnabled' do
    subject { build(:app_setting, name: 'RegistrationsEnabled') }

    it_behaves_like 'Boolean App Setting'
  end
end

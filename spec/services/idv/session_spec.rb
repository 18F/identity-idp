require 'rails_helper'

describe Idv::Session do
  let(:user) { build(:user) }
  let(:user_session) { {} }

  subject { Idv::Session.new(user_session: user_session, current_user: user, issuer: nil) }

  describe '#method_missing' do
    it 'disallows un-supported attributes' do
      expect { subject.foo = 'bar' }.to raise_error NoMethodError
    end

    it 'allows supported attributes' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        subject.send attr, 'foo'
        expect(subject.send(attr)).to eq 'foo'
        subject.send "#{attr}=".to_sym, 'foo'
        expect(subject.send(attr)).to eq 'foo'
      end
    end
  end

  describe '#respond_to_missing?' do
    it 'disallows un-supported attributes' do
      expect(subject.respond_to?(:foo=, false)).to eq false
    end

    it 'allows supported attributes' do
      Idv::Session::VALID_SESSION_ATTRIBUTES.each do |attr|
        expect(subject.respond_to?(attr, false)).to eq true
        expect(subject.respond_to?("#{attr}=".to_sym, false)).to eq true
      end
    end
  end

  describe '#complete_session' do
    context 'with phone verifed by vendor' do
      before do
        subject.address_verification_mechanism = :phone
        subject.vendor_phone_confirmation = true
        allow(subject).to receive(:complete_profile)
      end

      it 'completes the profile if the user has completed OTP phone confirmation' do
        subject.user_phone_confirmation = true
        subject.complete_session

        expect(subject).to have_received(:complete_profile)
      end

      it 'does not complete the profile if the user has not completed OTP phone confirmation' do
        subject.user_phone_confirmation = nil
        subject.complete_session

        expect(subject).not_to have_received(:complete_profile)
      end
    end

    context 'without a confirmed phone number' do
      before do
        subject.address_verification_mechanism = :phone
        subject.vendor_phone_confirmation = false
      end

      it 'does not complete the user profile' do
        allow(subject).to receive(:complete_profile)
        subject.complete_session
        expect(subject).not_to have_received(:complete_profile)
      end
    end
  end

  describe '#phone_confirmed?' do
    it 'returns true if the user and vendor have confirmed the phone' do
      subject.user_phone_confirmation = true
      subject.vendor_phone_confirmation = true

      expect(subject.phone_confirmed?).to eq(true)
    end

    it 'returns false if the user has not confirmed the phone' do
      subject.user_phone_confirmation = nil
      subject.vendor_phone_confirmation = true

      expect(subject.phone_confirmed?).to eq(false)
    end

    it 'returns false if the vendor has not confirmed the phone' do
      subject.user_phone_confirmation = true
      subject.vendor_phone_confirmation = nil

      expect(subject.phone_confirmed?).to eq(false)
    end

    it 'returns false if neither the user nor the vendor has confirmed the phone' do
      subject.user_phone_confirmation = nil
      subject.vendor_phone_confirmation = nil

      expect(subject.phone_confirmed?).to eq(false)
    end
  end

  describe '#address_mechanism_chosen?' do
    context 'phone verification chosen' do
      before do
        subject.address_verification_mechanism = 'phone'
      end

      it 'returns true if the vendor has confirmed the phone number' do
        subject.vendor_phone_confirmation = true

        expect(subject.address_mechanism_chosen?).to eq(true)
      end

      it 'returns false if the vendor has not confirmed the phone number' do
        subject.vendor_phone_confirmation = nil

        expect(subject.address_mechanism_chosen?).to eq(false)
      end
    end

    it 'returns true if the user has selected usps address verification' do
      subject.address_verification_mechanism = 'usps'

      expect(subject.address_mechanism_chosen?).to eq(true)
    end

    it 'returns false if the user has not selected phone or usps address verification' do
      subject.address_verification_mechanism = nil

      expect(subject.address_mechanism_chosen?).to eq(false)
    end
  end
end

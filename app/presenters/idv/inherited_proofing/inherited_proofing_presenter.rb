module Idv
  module InheritedProofing
    class InheritedProofingPresenter
      attr_reader :service_provider

      def initialize(service_provider:)
        @service_provider = service_provider
      end

      def learn_more_phone_or_mail_url
        'https://www.va.gov/resources/managing-your-vagov-profile/' if va_inherited_proofing?
      end

      def get_help_url
        'https://www.va.gov/resources/managing-your-vagov-profile/' if va_inherited_proofing?
      end

      def contact_support_url
        'https://www.va.gov/resources/managing-your-vagov-profile/' if va_inherited_proofing?
      end

      private

      def va_inherited_proofing?
        service_provider == :va
      end
    end
  end
end

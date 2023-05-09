module InPerson
  module EnrollmentsReadyForStatusCheck
    module UsesAnalytics
      def analytics(user: AnonymousUser.new)
        Analytics.new(user: user, request: nil, session: {}, sp: nil)
      end
    end
  end
end

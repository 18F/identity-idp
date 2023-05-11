module InPerson
  module EnrollmentsReadyForStatusCheck
    module UsesAnalytics
      # Create an analytics instance for logging
      # @param [User] user The user to associate the recorded analytics with.
      def analytics(user: AnonymousUser.new)
        Analytics.new(user: user, request: nil, session: {}, sp: nil)
      end
    end
  end
end

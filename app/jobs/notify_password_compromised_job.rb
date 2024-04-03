class NotifyPasswordCompromisedJob < ApplicationJob
	queue_as :long_running

	def perform(now)
		notifications_sent = 0
		User.joins(:emails).where(
			sql_query_for_users_eligible_to_verify_compromised,
			sign_in_date:,
		).each do |arr|
			
		end
	end
end
class NotifyPasswordCompromisedJob < ApplicationJob
	queue_as :long_running

	def perform(now)
		notifications_sent = 0
		Email.where(
			sql_query_for_users_eligible_to_verify_compromised,
			sign_in_date:,
		).each do |arr|
			
		end
	end

	private

	def sql_query_for_recently_signed_in_users_eligible_to_verify_compromised
	end
end
class RefreshVoterProfileJob < ApplicationJob
  queue_as :default

  def perform(voter_token)
    VoterProfile.refresh_for(voter_token)
  end
end

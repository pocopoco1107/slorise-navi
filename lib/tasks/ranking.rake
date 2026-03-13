namespace :ranking do
  desc "Refresh all voter rankings (weekly, monthly, all_time)"
  task refresh: :environment do
    $stdout.sync = true

    puts "Refreshing weekly rankings..."
    VoterRanking.refresh_weekly!
    puts "  Done: #{VoterRanking.weekly.count} entries"

    puts "Refreshing monthly rankings..."
    VoterRanking.refresh_monthly!
    puts "  Done: #{VoterRanking.monthly.count} entries"

    puts "Refreshing all-time rankings..."
    VoterRanking.refresh_all_time!
    puts "  Done: #{VoterRanking.all_time.count} entries"

    puts "Ranking refresh complete!"
  end
end

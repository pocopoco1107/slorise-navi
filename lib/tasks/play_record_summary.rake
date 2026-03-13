namespace :play_records do
  desc "Refresh all play record summaries"
  task refresh_summaries: :environment do
    $stdout.sync = true
    puts "Refreshing play record summaries..."
    PlayRecordSummary.refresh_all!
    puts "Done: #{PlayRecordSummary.count} entries"
  end
end

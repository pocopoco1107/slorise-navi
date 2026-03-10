# frozen_string_literal: true

# Batch execution logger that writes to log/batch_YYYYMMDD.log
# Designed for easy future integration with Slack/email notifications.
#
# Usage:
#   BatchLogger.with_logging("weekly_refresh") do |logger|
#     logger.info "Step 1 done"
#     logger.info "Step 2 done"
#     logger.summary(links_added: 10, links_removed: 3)
#   end
#
module BatchLogger
  class Logger
    attr_reader :task_name, :started_at, :log_file, :errors

    def initialize(task_name)
      @task_name = task_name
      @started_at = Time.current
      @errors = []
      @summary_data = {}

      log_dir = Rails.root.join("log")
      date_str = @started_at.strftime("%Y%m%d")
      @log_file = log_dir.join("batch_#{date_str}.log")
    end

    def info(message)
      write("[INFO] #{message}")
      puts message
    end

    def warn(message)
      write("[WARN] #{message}")
      puts "[WARN] #{message}"
    end

    def error(message)
      @errors << message
      write("[ERROR] #{message}")
      $stderr.puts "[ERROR] #{message}"
    end

    def summary(data = {})
      @summary_data.merge!(data)
    end

    def finish!
      elapsed = (Time.current - @started_at).round(1)
      lines = []
      lines << "Task: #{@task_name}"
      lines << "Duration: #{elapsed}s"
      lines << "Errors: #{@errors.size}"
      @summary_data.each { |k, v| lines << "  #{k}: #{v}" }
      if @errors.any?
        lines << "Error details:"
        @errors.first(10).each { |e| lines << "  - #{e}" }
      end

      result = lines.join("\n")
      write("[SUMMARY]\n#{result}")
      puts "\n" + "=" * 60
      puts result
      puts "=" * 60

      # Return structured result for future notification integration
      {
        task: @task_name,
        started_at: @started_at,
        finished_at: Time.current,
        duration_seconds: elapsed,
        errors: @errors,
        summary: @summary_data,
        success: @errors.empty?
      }
    end

    private

    def write(message)
      timestamp = Time.current.strftime("%Y-%m-%d %H:%M:%S")
      File.open(@log_file, "a") do |f|
        f.puts "[#{timestamp}] [#{@task_name}] #{message}"
      end
    end
  end

  # Main entry point. Wraps a batch task with logging and error handling.
  def self.with_logging(task_name)
    logger = Logger.new(task_name)
    logger.info "Started #{task_name}"

    result = yield(logger)

    logger.finish!
    result
  rescue => e
    logger.error "Unhandled exception: #{e.class}: #{e.message}"
    logger.error e.backtrace&.first(5)&.join("\n") if e.backtrace
    logger.finish!
    raise
  end
end

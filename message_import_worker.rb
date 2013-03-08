require 'resque'
require 'resque-retry'
require "resque-loner"
require "./import"

class MessageImportWorker
  include Resque::Plugins::UniqueJob
  @queue = :import_email

  @retry_limit = 3
  @retry_delay = 60

  def self.perform(options)
    importer = MessageImporter.new(options)
    importer.import! :after => options[:after], :before => options[:before]
  end

  def self.schedule!(options)
    user = options[:user]
    access_token = options[:access_token]
    start_date, end_date = MessageImporter.new(options).with_message_ids do |message_ids|
      start_time, end_time = [message_ids.first, message_ids.last].map do |message_id|
        Time.parse(imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE'].date)
      end
      [start_time.beginning_of_month, end_time.end_of_month]
    end

    count = 0
    while start_date < end_date
      break if options[:limit] and count >= options[:limit]
      count += 1
      next_date = start_date + 1.month
      puts "Scheduling from #{start_date} - #{next_date}"
      Resque.enqueue self, :user => user, :access_token => access_token, :after => start_date, :before => next_date
      start_date = next_date
    end
  end
end

if __FILE__ == $0
  Resque.inline = true
  MessageImportWorker.schedule! :address => 'oliver.steele@gmail.com', :access_token => ENV['GMAIL_ACCESS_TOKEN'], :limit => 1
end

require 'resque'
# require 'resque-retry'
require "resque-loner"
require "./import"

class MessageImportWorker
  include Resque::Plugins::UniqueJob
  @queue = :import_messages

  # @retry_limit = 3
  # @retry_delay = 60

  def self.perform(options)
    options = options.with_indifferent_access
    importer = MessageImporter.new(options)
    importer.import! :after => options[:after], :before => options[:before]
  end

  def self.schedule!(options)
    user = options[:user]
    account = Account.where(:user => options[:user]).first_or_create!
    start_date, end_date = MessageImporter.new(options).with_message_ids do |imap, message_ids|
      account.update_attributes :message_count => message_ids.length
      unless message_ids.any?
        puts "No messages"
        return
      end
      start_time, end_time = [message_ids.first, message_ids.last].map do |message_id|
        Date.parse(imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE'].date)
      end
      [start_time.beginning_of_month, end_time.end_of_month]
    end

    count = 0
    while start_date < end_date
      break if options[:limit] and count >= options[:limit]
      count += 1
      next_date = start_date + 1.month
      puts "Scheduling from #{start_date} - #{next_date}"
      Resque.enqueue MessageImportWorker, :user => user, :after => start_date, :before => next_date #, :ts => Time.now
      start_date = next_date
    end
  end
end

def main
  schedule_options = { :user => 'oliver.steele@gmail.com' }

  OptionParser.new do|opts|
    opts.on('-n', '--limit N', "Limit to N jobs") do |n| schedule_options[:limit] = n.to_i end
    opts.on('-u', '--user USER') do |user| schedule_options[:user] = user end
    opts.on('--inline') do Resque.inline = true end

    opts.on('-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end.parse!

  MessageImportWorker.schedule! schedule_options
end

main if __FILE__ == $0

require './app'
require 'gmail'
require 'active_support'
require 'resque'
require "resque-loner"
require './models'

class MessageImporter
  include Resque::Plugins::UniqueJob
  @queue = :import_email

  def self.perform(options)
    importer = self.new(options)
    importer.import! :after => options[:after], :before => options[:before]
  end

  def initialize(options)
    @address = options[:address]
    @password = options[:password]
  end

  def connection(&block)
    # raise "connecting with address=#{@address.inspect} password=#{@password.inspect}"
    Gmail.connect!(@address, @password) do |gmail| yield gmail end
  end

  def import!(options={})
    message_options = {}
    message_options[:after] = Date.parse(options[:after]) if options[:after]
    message_options[:before] = Date.parse(options[:before]) if options[:before]
    connection do |gmail|
      for message in gmail.mailbox('[Gmail]/All Mail').emails(message_options)
        puts "Skipping #{message.uid}" if Message.exists?(message.uid)
        next if Message.exists?(message.uid)
        recipients = message.to || []
        puts "#{message.uid} #{Date.parse(message.date)} #{message.from.first.name} #{message.subject} #{recipients.map(&:name)}"
        raise "Multiple senders for #{message.uid}" if message.from.length != 1
        sender = Address.from_imap_address(message.from.first)
        recipients = recipients.map { |address| Address.from_imap_address(address) }
        Message.transaction do
          message = Message.create(:uid => message.uid, :subject => message.subject, :date => message.date, :sender_id => sender.id)
          message.recipients = recipients
        end
      end
    end
  end

  def spawn!
    start_date = nil
    end_date = nil
    connection do |gmail|
      messages = gmail.mailbox('[Gmail]/All Mail').emails
      start_date = Time.parse(messages.first.date).beginning_of_month
      end_date = Time.parse(messages.last.date).end_of_month
    end
    date = start_date
    while date < end_date
      Resque.enqueue(self.class, :address => @address, :password => @password, :after => date, :before => date + 1.month)
      break
    end
  end
end

if __FILE__ == $0
  importer = MessageImporter.new(:address => 'oliver.steele@gmail.com', :password => ENV['GMAIL_PASSWORD'])
  if ARGV[0] == '--spawn'
    importer.spawn!
  else
    Schema.new.change unless File.exists?('db/data.sqlite3')
    importer.import! #:after => "2012-10-01"
  end
end

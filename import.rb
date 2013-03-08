require './app'
require 'mail'
require 'gmail'
require 'active_support'
require './models'

class MessageImporter
  def initialize(options)
    @user = options[:user]
    @access_token = options[:access_token]
    @mailbox = '[Gmail]/All Mail'
  end

  def connection(&block)
    imap = Net::IMAP.new('imap.gmail.com', 993, usessl=true, certs=nil, verify=false)
    imap.authenticate('XOAUTH2', @user, @access_token)
    imap.select(@mailbox)
    yield imap
  ensure
    imap.expunge rescue nil
  end

  def with_message_ids(options={}, &block)
    connection do |imap|
      message_ids = imap.search('ALL')
      yield message_ids
    end
  end

  def import!(options={})
    search_options = []
    search_options += ['BEFORE', Date.parse(options[:before]).strftime('%Y-%m-%d')] if options[:before]
    search_options += ['SINCE', Date.parse(options[:after]).strftime('%Y-%m-%d')] if options[:after]
    search_options << 'ALL' unless search_options.any?
    count = 0
    connection do |imap|
      for message_id in imap.search(search_options)
        puts "Skipping #{message_id}" if Message.exists?(message_id) and count > 0
        next if Message.exists?(message_id)
        count += 1
        message = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
        recipients = message.to || []
        puts "#{message_id} #{Date.parse(message.date)} #{message.from.first.name} #{message.subject} #{recipients.map(&:name)}"
        raise "Multiple senders for #{message_id}" if message.from.length != 1
        sender = Address.from_imap_address(message.from.first)
        recipients = recipients.map { |address| Address.from_imap_address(address) }
        Message.transaction do
          message = Message.create(:uid => message_id, :subject => message.subject, :date => message.date, :sender_id => sender.id)
          message.recipients = recipients
        end
      end
    end
  end
end

if __FILE__ == $0
  importer = MessageImporter.schedule! :address => 'oliver.steele@gmail.com', :access_token => ENV['GMAIL_ACCESS_TOKEN']
  Schema.new.change unless File.exists?('db/data.sqlite3')
  importer.import!
end

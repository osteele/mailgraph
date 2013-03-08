require './app'
require 'mail'
require 'gmail'
require 'active_support'
require './models'

class MessageImporter
  attr_reader :user

  def initialize(options)
    @user = options[:user]
    @mailbox = '[Gmail]/All Mail'
  end

  def connection(&block)
    token = Token.find_by_user(user)
    raise "No token for #{user.inspect}" unless token
    access_token = token.access_token
    imap = Net::IMAP.new('imap.gmail.com', 993, usessl=true, certs=nil, verify=false)
    imap.authenticate('XOAUTH2', user, access_token)
    imap.select(@mailbox)
    yield imap
  ensure
    imap.expunge rescue nil
  end

  def with_message_ids(options={}, &block)
    search_options = []
    search_options += ['BEFORE', Net::IMAP.format_datetime(Date.parse(options[:before]))] if options[:before]
    search_options += ['SINCE', Net::IMAP.format_datetime(Date.parse(options[:after]))] if options[:after]
    search_options << 'ALL' unless search_options.any?
    connection do |imap|
      message_ids = imap.search(search_options)
      yield imap, message_ids
    end
  end

  def import!(options={})
    count = 0
    with_message_ids(options) do |imap, message_ids|
      for message_id in message_ids
        if Message.exists?(:uid => message_id)
          puts "Skipping #{message_id}" and count > 0
          next
        end
        count += 1
        message = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
        recipients = message.to || []
        puts "#{message_id} #{Date.parse(message.date)} #{message.from.first.name} #{message.subject} #{recipients.map(&:name)}"
        raise "Multiple senders for #{message_id}" unless message.from.length == 1
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
  importer = MessageImporter.schedule! :address => 'oliver.steele@gmail.com'
  Schema.new.change unless File.exists?('db/data.sqlite3')
  importer.import!
end

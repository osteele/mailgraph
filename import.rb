require 'pp'
require './app'
require 'mail'
require 'google/api_client'
require 'active_support'
require './models'
require './patch_imap_for_gmail'

class MessageImporter
  attr_reader :user

  def initialize(options)
    @user = options[:user]
    @mailbox = '[Gmail]/All Mail'
  end

  def with_imap(&block)
    self.renew_access_token!
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
    with_imap do |imap|
      message_ids = imap.search(search_options)
      yield imap, message_ids
    end
  end

  def renew_access_token!
    token = Token.find_by_user(user)
    return if token.expires_at > Time.now + 30.seconds

    client = Google::APIClient.new
    auth = client.authorization
    auth.client_id = '641654287458-oq3atarvk2lm55ld2qt2ektmm8nrs3a7.apps.googleusercontent.com'
    auth.client_secret = 'xHdPdx_bZi6rPFla0-sFPery'
    auth.redirect_uri = "urn:ietf:oauth:2.0:oob"
    auth.scope = ['https://mail.google.com/', 'https://www.googleapis.com/auth/userinfo.email']

    auth.update_token! :access_token => token.access_token, :refresh_token => token.refresh_token #, :expires_at => Time.now - 1.minute
    auth.fetch_access_token!
    token.update_attributes :access_token => auth.access_token, :expires_at => Time.now + auth.expires_in.seconds
  end

  def import_message_headers!(options={})
    with_message_ids(options) do |imap, message_ids|
      # puts "Winnowing #{message_ids.length}"
      message_ids = message_ids.reject { |id| Message.exists?(:uid => id) }
      puts "Retrieving #{message_ids.length} headers"
      message_ids.each_slice(500) do |slice_ids|
        # p "Fetching #{slice_ids.inspect}"
        for message in (imap.fetch(slice_ids, ['ENVELOPE', 'X-GM-MSGID']) || [])
          message_id = message.seqno
          envelope = message.attr['ENVELOPE']
          recipients = envelope.to || []
          date = nil
          date = Date.parse(envelope.date) rescue nil
          next unless date
          puts "#{message_id} #{Date.parse(envelope.date)} #{envelope.from.first.name} #{envelope.subject} #{recipients.map(&:name)}"
          raise "Multiple senders for #{message_id}" unless envelope.from.length == 1
          sender = Address.from_imap_address(envelope.from.first)
          recipients = recipients.map { |address| Address.from_imap_address(address) }
          begin
            Message.transaction do
              record = Message.create(
                :uid => message_id,
                :subject => envelope.subject,
                :date => envelope.date,
                :sender_id => sender.id,
                :gm_message_id => message.attr['X-GM-MSGID'])
              record.recipients = recipients
            end
          rescue SQLite3::ConstraintException => e
            raise unless e.to_s =~ /column uid is not unique/
          end
        end
      end
    end
  end

  def add_field!(imap_attribute, record_attribute)
    with_imap do |imap|
      Message.where(record_attribute => nil).find_in_batches(:batch_size => 1000) do |records|
        messages = imap.fetch(records.map(&:uid), imap_attribute) || []
        messages.each do |message|
          record = records.find { |r| r.uid == message.seqno }
          value = message.attr[imap_attribute]
          puts "Message #{record.uid} #{record_attribute}=#{value.inspect}"
          record.update_attributes record_attribute => value if value
        end
      end
    end
  end
end

def main
  options = { :user => 'oliver.steele@gmail.com' }
  search_options = {}

  OptionParser.new do|opts|
    opts.on('--since DATE') do |date| search_options[:after] = date end
    opts.on('--after DATE') do |date| search_options[:after] = date end
    opts.on('--before DATE') do |date| search_options[:before] = date end
    opts.on('-u', '--user USER') do |user| options[:user] = user end

    opts.on('-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end.parse!

  Schema.new.change unless File.exists?('db/data.sqlite3')
  importer = MessageImporter.new(options)
  importer.import_message_headers! search_options
  # importer.add_field! 'X-GM-MSGID', :gm_message_id
end

main if __FILE__ == $0

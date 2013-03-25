require 'mail'
require 'pp'
require 'active_support'
require './app'
require './models'
require './patch_imap_for_gmail'
require './oauth_utils'
require './utils'

class MessageImporter
  include Logging
  attr_reader :email_address, :mailbox_name

  def initialize(options)
    @email_address = options[:email_address]
    @mailbox_name = options[:mailbox_name] || :All #'[Gmail]/All Mail'
  end

  def mailboxes
    with_imap do |imap|
      return imap.list('', '*')
    end
  end

  def with_imap(&block)
    access_token = GoogleOAuthToken::find_access_token_by_email_address(email_address)
    # TODO pool imap connections
    imap = Net::IMAP.new('imap.gmail.com', 993, usessl=true, certs=nil, verify=false)
    imap.authenticate('XOAUTH2', email_address, access_token)
    yield imap
  ensure
    imap.expunge rescue nil
  end

  def with_mailbox(&block)
    with_imap do |imap|
      mailboxes = imap.list('', '*')
      mailbox = case mailbox_name
          when Symbol then mailboxes.find { |m| m.attr.include?(mailbox_name) }
          when String then mailboxes.find { |m| m.name == mailbox_name }
          else raise "Program error: can't search for mailbox #{mailbox_name.inspect} #{mailbox_name.class}"
        end
      raise "No mailbox #{mailbox_name}; valid mailboxes are #{mailboxes.map(&:name).join(", ")}" unless mailbox
      imap.select(mailbox.name)
      yield imap
    end
  end

  def with_message_ids(options={}, &block)
    search_options = []
    search_options += ['BEFORE', Net::IMAP.format_datetime(Date.parse(options[:before]))] if options[:before]
    search_options += ['SINCE', Net::IMAP.format_datetime(Date.parse(options[:after]))] if options[:after]
    search_options << 'ALL' unless search_options.any?
    with_mailbox do |imap|
      logger.info "Searching mailbox #{mailbox_name} for #{search_options.inspect}"
      message_ids = imap.search(search_options)
      yield imap, message_ids
    end
  end

  def import_message_headers!(options={})
    count = 0
    limit = options[:limit]
    account = Account.where(:email_address => email_address).first_or_create!
    with_message_ids(options) do |imap, message_ids|
      logger.info "Retrieving #{message_ids.length} messages"
      message_ids.each_slice(1000) do |slice_ids|
        break if limit and count >= limit
        logger.info "Fetching messages #{slice_ids.first}..#{slice_ids.last}" if slice_ids.any?
        for message in (imap.fetch(slice_ids, ['ENVELOPE', 'UID', 'X-GM-MSGID', 'X-GM-THRID']) || [])
          break if limit and count >= limit
          count += 1
          next if Message.exists?(:account_id => account.id, :gm_message_id => message.attr['X-GM-MSGID'])
          envelope = message.attr['ENVELOPE']
          uid = message.attr['UID']
          raise "Multiple senders for #{uid}" unless envelope.from.length == 1
          recipients = envelope.to || []
          date = Date.parse(envelope.date) rescue nil
          sender = envelope.from.first
          logger.info "#{uid} #{date} From: #{sender.mailbox}@#{sender.host} #{envelope.subject.inspect} To: #{recipients.map { |a| "#{a.mailbox}@#{a.host}" }.join('+')}"
          begin
            Message.transaction do
              record = Message.create(
                :account_id => account.id,
                :uid => uid,
                :subject => envelope.subject,
                :date => envelope.date,
                :gm_message_id => message.attr['X-GM-MSGID'],
                :gm_thread_id  => message.attr['X-GM-THRID']
                )
              for field in %w[from to cc bcc]
                for address in envelope.send(field) || []
                  MessageAssociation.create :message => record, :address => Address.from_imap_address(address), :field => field
                end
              end
            end
          rescue SQLite3::ConstraintException => e
            raise unless e.to_s =~ /column uid is not unique/
          end
        end
      end
    end
    Address.combine_addresses!
  end

  def add_field!(imap_attribute, record_attribute)
    with_mailbox do |imap|
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
  options = { :email_address => 'oliver.steele@gmail.com' }
  import_options = {}
  action = :import

  OptionParser.new do|opts|
    opts.on('--since DATE') do |date| import_options[:after] = date end
    opts.on('--after DATE') do |date| import_options[:after] = date end
    opts.on('--before DATE') do |date| import_options[:before] = date end
    opts.on('-n', '--limit N') do |limit| import_options[:limit] = limit.to_i end
    opts.on('-m', '--mailbox NAME') do |name|
      name = $1.to_sym if name =~ /^:(.+)$/
      options[:mailbox_name] = name
    end
    opts.on('--mailboxes') do action = :mailboxes end
    opts.on('-u', '--user USER') do |user| options[:email_address] = user end

    opts.on('-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end.parse!

  Schema.new.change unless File.exists?('db/data.sqlite3')
  importer = MessageImporter.new(options)
  case action
  when :import then importer.import_message_headers! import_options
  when :mailboxes then pp importer.mailboxes
  else raise "Program error: unknown action #{action}"
  end
  # importer.add_field! 'X-GM-MSGID', :gm_message_id
end

main if __FILE__ == $0
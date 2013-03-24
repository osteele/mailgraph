require 'mail'
require 'active_support'
require './app'
require './models'
require './patch_imap_for_gmail'
require './oauth_utils'

class MessageImporter
  attr_reader :email_address

  def initialize(options)
    @email_address = options[:email_address]
    @mailbox = options[:mailbox] || '[Gmail]/All Mail'
  end

  def with_imap(&block)
    access_token = GoogleOAuthToken::find_access_token_by_email_address(email_address)
    # TODO pool imap connections
    imap = Net::IMAP.new('imap.gmail.com', 993, usessl=true, certs=nil, verify=false)
    imap.authenticate('XOAUTH2', email_address, access_token)
    mailbox = @mailbox
    mailbox_names = imap.list('', '*').map(&:name)
    raise "No mailbox #{mailbox}; valid mailboxes are #{mailbox_names.join(", ")}" unless mailbox_names.include?(mailbox)
    imap.select(mailbox)
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

  def import_message_headers!(options={})
    count = 0
    limit = options[:limit]
    account = Account.where(:email_address => email_address).first_or_create!
    with_message_ids(options) do |imap, message_ids|
      account.update_attributes :message_count => message_ids.length
      message_ids = message_ids.reject { |id| Message.exists?(:account_id => account.id, :uid => id) }
      puts "Retrieving #{message_ids.length} headers"
      message_ids.each_slice(1000) do |slice_ids|
        break if limit and count >= limit
        for message in (imap.fetch(slice_ids, ['ENVELOPE', 'X-GM-MSGID', 'X-GM-THRID']) || [])
          break if limit and count >= limit
          count += 1
          message_id = message.seqno
          envelope = message.attr['ENVELOPE']
          raise "Multiple senders for #{message_id}" unless envelope.from.length == 1
          recipients = envelope.to || []
          date = Date.parse(envelope.date) rescue nil
          puts "#{message_id} #{date} #{envelope.from.first.name} #{envelope.subject} #{recipients.map { |a| "#{a.mailbox}@{a.host}" }}"
          begin
            Message.transaction do
              record = Message.create(
                :account_id => account.id,
                :uid => message_id,
                :subject => envelope.subject,
                :date => envelope.date,
                # :sender => sender,
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
  options = { :email_address => 'oliver.steele@gmail.com' }
  import_options = {}

  OptionParser.new do|opts|
    opts.on('--since DATE') do |date| import_options[:after] = date end
    opts.on('--after DATE') do |date| import_options[:after] = date end
    opts.on('--before DATE') do |date| import_options[:before] = date end
    opts.on('-n', '--limit N') do |limit| import_options[:limit] = limit.to_i end
    opts.on('--mailbox MAILBOX') do |mailbox| options[:mailbox] = mailbox end
    opts.on('-u', '--user USER') do |user| options[:email_address] = user end

    opts.on('-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
  end.parse!

  Schema.new.change unless File.exists?('db/data.sqlite3')
  importer = MessageImporter.new(options)
  importer.import_message_headers! import_options
  # importer.add_field! 'X-GM-MSGID', :gm_message_id
end

main if __FILE__ == $0

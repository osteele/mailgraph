require 'gmail'
require './models'

Schema.new.change unless File.exists?('db/data.sqlite3')

gmail = Gmail.connect!('oliver.steele@gmail.com', ENV['GMAIL_PASSWORD'])

# Message.delete_all

# sender = Address.where(:name => "Oliver", :address => "steele@osteele.com", :host => 'osteele.com').first_or_create
# recipient = Address.where(:name => "Margaret", :address => "marg@media.mit.edu", :host => 'media.edu').first_or_create
# message = Message.create(:subject => "Subject", :sender_id => sender.id)
# message.recipients = [recipient]

# exit

for message in gmail.mailbox('[Gmail]/All Mail').emails
  next if Message.exists?(message.uid)
  puts "#{message.uid} #{Date.parse(message.date)} #{message.from.first.name} #{message.subject} #{message.to.map(&:name)}"
  raise "Multiple senders for #{message.uid}" if message.from.length != 1
  sender = Address.from_imap_address(message.from.first)
  recipients = message.to.map { |address| Address.from_imap_address(address) }
  Message.transaction do
    message = Message.create(:uid => message.uid, :subject => message.subject, :date => message.date, :sender_id => sender.id)
    message.recipients = recipients
  end
end

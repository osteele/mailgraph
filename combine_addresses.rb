require 'bundler/setup'
require './config/environments'
require './models'

email_address = 'oliver.steele@gmail.com'
account = Account.where(:email_address => email_address).first_or_create!

for contact in Contact.find(:all)
  next unless contact.addresses.count > 1
  # puts "Could combine #{contact.name}"
  contact puts.addresses.pluck(:spec)
end

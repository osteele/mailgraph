require './models'

span = [Message.first(:order => :date).date, Message.last(:order => :date).date]
days = (span[1] - span[0]) / 3600 / 24

# find the most frequent recipients
# create a temporary table with (recipient_id, )

day = span[0]
while day <= span[1]
  puts "#{day} #{Message.where("date >= ? and date < ?", day, day + 1.day).count}"
  day += 1.day
end

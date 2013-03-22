class EmailAnalyzer
  attr_reader :user

  def initialize(user)
    @user = user
  end

  def series(start_date, end_date, limit)
    start_date ||= user.messages.where('date IS NOT NULL AND date > "1975-01-01"').first(:order => :date).date.beginning_of_year
    end_date ||= user.messages.last(:order => 'date').date
    stats = {}
    map = {}
    account_address = Address.find_by_spec(user.email_address).canonicalize
    while start_date < end_date
      next_date = start_date + 1.month
      results = Message.connection.select_all(<<-"SQL", nil, [[nil, user.id], [nil, start_date], [nil, next_date], [nil, account_address.id]])
        SELECT spec, addresses.id, addresses.canonical_address_id, COUNT(*) AS count FROM addresses
        JOIN message_associations ON address_id=addresses.id
        JOIN messages ON message_id=messages.id
        WHERE messages.account_id = $1 AND $2 <= messages.date AND messages.date < $3
        AND domain_name IS NOT NULL
        AND addresses.id != $4 AND (canonical_address_id IS NULL OR canonical_address_id != $4)
        GROUP BY (CASE WHEN canonical_address_id IS NOT NULL THEN canonical_address_id ELSE addresses.id END)
        ORDER BY COUNT(*) DESC
        LIMIT 15
      SQL
      for record in results
        record["spec"] = map[record["canonical_address_id"]] ||= Address.find(record["canonical_address_id"]).spec if record["canonical_address_id"] and record["canonical_address_id"] != record["id"]
      end
      stats[start_date.strftime("%Y-%m")] = results.inject({}) { |h, r| h[r["spec"].to_s] = r["count"]; h }
      start_date = next_date
    end
    names = stats.map { |date, counts| counts.keys }.flatten.uniq
    names = names.inject({}) do |h, name|
      h[name] = stats.map { |_, x| x[name] }.compact.sum
      h
    end.to_a.sort { |a, b| b[1] <=> a[1] }[0...limit].map { |name, _| name }
    series = names.map do |name|
      {
        :key => name,
        :values => stats.map { |date, x| {date: date, count: x[name] || 0} }
      }
    end
    return series
  end
end

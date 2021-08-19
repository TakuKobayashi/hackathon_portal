# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

sql_files = Dir.glob(Rails.root.join('db', 'seeds', '**', '*.sql'))
sql_files.each do |sql_file|
  sql = File.open(sql_file, &:read)

  # split multiple queries
  queries = sql.split(/\n/)

  ActiveRecord::Base.transaction do
    queries.each do |q|
      next if q.blank?
      result = ActiveRecord::Base.connection.execute(q)
    end
  end
end

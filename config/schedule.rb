# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, "#{path}/log/cron.log"
#set :rbenv_root, "/app/library/rbenv"

#if defined? :rbenv_root
#  job_type :rake,    %{cd :path && :environment_variable=:environment :rbenv_root/bin/rbenv exec bundle exec rake :task --silent :output}
#  job_type :runner,  %{cd :path && :rbenv_root/bin/rbenv exec bundle exec rails runner -e :environment ':task' :output}
#  job_type :script,  %{cd :path && :environment_variable=:environment :rbenv_root/bin/rbenv exec bundle exec script/:task :output}
#end

every :day, at: '10:00' do
  rake "batch:event_crawl"
end

every :day, at: '15:00' do
  rake "backup:update_table_to_spreadsheet"
end

every :day, at: '19:00' do
  rake "batch:bot_tweet"
end

every :day, at: '22:00' do
  rake "backup:dump_and_upload_and_clear_data"
end

every 3.hours do
  runner "Ai::TwitterResource.crawl_hashtag_tweets!"
end
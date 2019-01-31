namespace :backup do
  task ai_dump_and_upload_and_clear_data: :environment do
  end

  task upload_event_spreadsheet: :environment do
    Event.find_each do |event|
      # write spread sheet
    end
  end
end
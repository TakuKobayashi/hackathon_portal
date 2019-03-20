namespace :backup do
  task dump_and_upload_and_clear_data: :environment do
    backup_models = [
      Ai::AppearWord,
      Ai::HashtagTrigram,
      Ai::Hashtag,
      Ai::ResourceAttachment,
      Ai::ResourceHashtag,
      Ai::ResourceSentence,
      Ai::ResourceSummary,
      Ai::Trigram,
      Ai::TweetResource,
    ]
    BackupToGoogleServices.backup_and_upload_and_clear_data!(backup_models: backup_models)
  end

  task update_table_to_spreadsheet: :environment do
    backup_models = [Event, Scaling::UnityEvent]
    BackupToGoogleServices.backup_table_to_spreadsheet!(backup_models: backup_models)
  end
end

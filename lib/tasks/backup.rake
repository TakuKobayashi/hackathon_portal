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

  task cd_git_commit_and_push: :environment do
    git = Git.open(Rails.root.to_s)
    git.add(Rails.root.join("db", "seeds"))
    git.commit("update " + Time.current.strftime("%Y%m%d %H:%M:%S") + " crawled data")
    git.push(git.remote('master'))
  end
end

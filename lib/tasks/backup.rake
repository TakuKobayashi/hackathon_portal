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

  task all_models_split_sql_files: :enviroment do
    Rails.application.eager_load!
    model_classes = ActiveRecord::Base.descendants.select{|m| m.table_name.present? }.uniq{|m| m.table_name }
    model_classes.each do |model_class|
      column_names = model_class.column_names
      backup_table_directory_name = Rails.root.join("backup", model_class.table_name)
      unless Dir.exists?(backup_table_directory_name)
        Dir.mkdir(backup_table_directory_name)
      end
      model_class.find_in_batches do |models|

      end
    end
  end
end

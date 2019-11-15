class RemoveColumnJudgeStateFromEvent < ActiveRecord::Migration[6.0]
  def change
    remove_column :events, :judge_state
  end
end

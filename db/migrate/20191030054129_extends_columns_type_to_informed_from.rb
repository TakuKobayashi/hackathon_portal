class ExtendsColumnsTypeToInformedFrom < ActiveRecord::Migration[6.0]
  def up
    add_column :events, :informed_from, :integer, null: false, default: 0
    add_column :scaling_unity_events, :informed_from, :integer, null: false, default: 0
    [Event, Scaling::UnityEvent].each do |clazz|
      clazz.find_each do |event|
        if event.type.include?('Atnd')
          event.atnd!
        elsif event.type.include?('Connpass')
          event.connpass!
        elsif event.type.include?('Doorkeeper')
          event.doorkeeper!
        elsif event.type.include?('Peatix')
          event.peatix!
        elsif event.type.include?('Meetup')
          event.meetup!
        elsif event.type.include?('GoogleFormEvent')
          event.google_form!
        elsif event.type.include?('TwitterEvent')
          event.twitter!
        end
      end
    end
  end

  def down
    [Event, Scaling::UnityEvent].each do |clazz|
      clazz.find_each do |event|
        if event.atnd?
          type.update!(type: 'Atnd')
        elsif event.connpass?
          type.update!(type: 'Connpass')
        elsif event.doorkeeper?
          type.update!(type: 'Doorkeeper')
        elsif event.peatix?
          type.update!(type: 'Peatix')
        elsif event.meetup?
          type.update!(type: 'Meetup')
        elsif event.type.google_form?
          type.update!(type: 'GoogleFormEvent')
        elsif event.type.twitter?
          type.update!(type: 'TwitterEvent')
        else
          type.update!(type: 'SelfPostEvent')
        end
      end
    end
    remove_column :events, :informed_from
    remove_column :scaling_unity_events, :informed_from
  end
end

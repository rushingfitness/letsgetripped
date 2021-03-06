class Day < ActiveRecord::Base

  has_many :exercises,       :dependent => :destroy
  has_one  :cardio,          :dependent => :destroy
  has_one  :super_challenge, :dependent => :destroy
  has_many :meals,           :dependent => :destroy
  has_many :calf_crunches,   :dependent => :destroy
  has_many :pushups,         :dependent => :destroy

  def self.get_daily_stats(current_user,day_id)
    current_user.days
        .select("days.*, COUNT(super_challenges.id) as super_challenge_total, COUNT(cardios.id) as cardio_total, COUNT(exercises.id) as exercise_total, COUNT(calf_crunches.id) as calf_crunch_total, ROUND(COALESCE(SUM((meals.protein * 4)+(meals.fats * 9)+(meals.carbs * 4)),0),2) as calories, ROUND(COALESCE(SUM(meals.protein),0),2) as protein, ROUND(COALESCE(SUM(meals.carbs),0),2) as carbs, ROUND(COALESCE(SUM(meals.fats),0),2) as fats")
        .where("days.id = '#{day_id}'")
        .joins("LEFT JOIN meals on meals.day_id = days.id")
        .joins("LEFT JOIN calf_crunches on calf_crunches.day_id = days.id")
        .joins("LEFT JOIN cardios on cardios.day_id = days.id")
        .joins("LEFT JOIN exercises on exercises.day_id = days.id")
        .joins("LEFT JOIN super_challenges ON super_challenges.day_id = days.id").first
  end

  def self.get_weekly_stats(current_user)
    ctr = 0
    cardio = current_user.days
          .select("WEEK(days.date,1) as week, COUNT(exercises.id) as exercise_total, COUNT(cardios.id) as cardio_total, COUNT(cardios.id) as cardio_total, ROUND(COALESCE((SUM(cardios.distance)/COUNT(cardios.id)),0),2) as avg_cardio_dist, ROUND(COALESCE((SUM(cardios.distance)/COUNT(cardios.id) * 3),0),2) as avg_cardio_speed")
          .joins("LEFT JOIN cardios on cardios.user_id = #{current_user.id} AND cardios.day_id = days.id")
          .joins("LEFT JOIN exercises on exercises.user_id = #{current_user.id} AND exercises.day_id = days.id")
          .group("WEEK(days.date,1)")
          .order("WEEK(days.date,1)")

    x = current_user.days
          .select("days.date as date,COUNT(DISTINCT(meals.id)) as meal_total,ROUND(COALESCE(SUM((meals.protein * 4)+(meals.fats * 9)+(meals.carbs * 4)),0),2) as calories,super_challenges.id AS sc_id, previous_sc.id AS previous_sc_id, super_challenges.date AS sc_date, previous_sc.date AS previous_sc_date,super_challenges.duration AS duration,super_challenges.push_ups AS push_ups, super_challenges.pull_ups AS pull_ups, previous_sc.duration AS previous_sc_duration, previous_sc.push_ups AS previous_sc_push_ups,previous_sc.pull_ups AS previous_sc_pull_ups")
          .joins("LEFT JOIN meals on meals.day_id = days.id")
          .joins("LEFT OUTER JOIN super_challenges ON super_challenges.user_id = #{current_user.id} AND WEEK(super_challenges.date,1) = WEEK(days.date,1)")
          .joins("LEFT OUTER JOIN super_challenges AS previous_sc ON previous_sc.user_id = #{current_user.id} AND WEEK(previous_sc.date,1) = (WEEK(days.date,1) - 1)")
          .group("WEEK(days.date,1)")
          .order("WEEK(days.date,1)")

    x.map do |f|
      string = "<ul><strong>Week #{ctr} (#{f.date.beginning_of_week.strftime('%m/%d/%Y')}):</strong><ul>"
      string += "<li>Total Calories: #{f.calories}</li><li>Total Meals Eaten: #{f.meal_total}</li>"
      if (f.meal_total != 0)
        string +="<li>Average Calorie Per Meal: #{(f.calories / f.meal_total).round(2)}</li>"
      end

      if f.sc_id # if there was a SC this week
        if f.previous_sc_id # If there was a SC this week and last week
          if score(f) >= 0
            string += "<li>Super Challenge Comparison to previous week: <ul><li>#{time(f)}</li><li>+#{score(f)} points</li></ul></li>"
          else 
            string += "<li>Super Challenge Comparison to previous week: <ul><li>#{time(f)}</li><li>#{score(f)} points</li></ul></li>"
          end
        else # If there was a SC this week but not last week
          string += "<li><i>No Challenge completed in prior week</i></li>"
        end
      elsif f.previous_sc_id # This week no SC but last week there was
        string +="<li><i>Super Challenge Not Completed This Week but there was one last week</i></li>"
      else
        string +="<li><i>Super Challenge Not Completed This Week</i></li>"
      end

      string +="<li>Total Exercises Done: #{cardio[ctr].exercise_total}</li><li>Total Cardios Done: #{cardio[ctr].cardio_total}</li>
                <li>Average Cardio Distance: #{cardio[ctr].avg_cardio_dist} Miles</li><li>Average Cardio Speed: #{cardio[ctr].avg_cardio_speed} mph</li></ul></ul>"
      ctr += 1
      string.html_safe
    end
  end

  def self.score(type)
    if type.duration
      if type.duration.to_i > 18
        new_time = 100 - ((type.duration * 60 - 1080) / 10).to_i
        new_time = 0 if new_time < 0
      else
        new_time = 100
      end
    else
      new_time = 0
    end
    if type.push_ups.to_i >= 50
      new_push_ups = 100
    else
      new_push_ups = type.push_ups.to_i * 2 || 0
    end
    if type.pull_ups.to_i >= 20
      new_pull_ups = 100
    else
      new_pull_ups = type.pull_ups.to_i * 5 || 0
    end
    if type.previous_sc_duration
      if type.previous_sc_duration.to_i > 18
        old_time = 100 - ((type.previous_sc_duration * 60 - 1080) / 10).to_i
        old_time = 0 if old_time < 0
      else
        old_time = 100
      end
    else
      old_time = 0
    end
    if type.previous_sc_push_ups.to_i >= 50
      old_push_ups = 100
    else
      old_push_ups = type.previous_sc_push_ups.to_i * 2 || 0
    end
    if type.previous_sc_pull_ups.to_i >= 20
      old_pull_ups = 100
    else
      old_pull_ups = type.previous_sc_pull_ups.to_i * 5 || 0
    end
    return ((new_pull_ups + new_push_ups + new_time)-(old_pull_ups + old_push_ups + old_time))
  end

  def self.time(challenge)
    time = (challenge.duration - challenge.previous_sc_duration).round(2)
    hours = (time / 60.0).to_i
    minutes = (time / 60.0).to_f
    seconds = (60 * (minutes - hours)).to_f
    minutes = (60 * (minutes - hours)).to_i
    seconds = (60 * (seconds- minutes)).round()

    if (hours != hours.abs) || (minutes != minutes.abs) || (seconds != seconds.abs)
      return "-#{hours.abs} Hours, #{minutes.abs} Minutes, #{seconds.abs} Seconds"
    else
      return "+#{hours} Hours, #{minutes} Minutes, #{seconds} Seconds"
    end
  end
end

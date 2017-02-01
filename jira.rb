require 'curb'
require 'json'
require 'date'
require 'colorize'

$url = ARGV[0]
$user = ARGV[1]
$password = ARGV[2]
$morning_hour = 9

if ARGV.count != 3
    puts 'wrong number of parameters'.red
    puts 'USAGE:'.green
    puts 'ruby jira.rb http://yourjira.atlassian.net your@gmail.com yourpassword'
    exit(0)
end

def date_to_str(date)
    return date.strftime("%d-%m-%Y %H:%M")
end

def hours_to_str(hours)
    return "#{hours > 9 ? '' : ' '}#{hours} #{hours == 1 ? 'hour' : 'hours'}".green
end

def parse_date(date_str)
    date_str = date_str.chomp('00') + ":00"
    result = DateTime.parse(date_str)
    result = result.new_offset(Time.now.utc_offset / (60 * 60 * 24.0))
    return result
end

def get_number_of_days(date = Date.today)
  Date.new(date.year, date.month, -1).mday
end

def load_issues
    request = {
        "jql": "worklogAuthor = currentUser()",
        "startAt": 0,
        "maxResults": 1000,
        "fields": [
            "project",
            "summary",
            "status",
            "assignee",
            "worklog"
        ]
    }

    c = Curl::Easy.http_post("#{$url}/rest/api/2/search", request.to_json)
    c.http_auth_types = :basic
    c.headers["Content-Type"] = "application/json"
    c.username = $user
    c.password = $password
    c.verbose = false
    c.perform
    result =  JSON.parse(c.body_str)

    issues = result["issues"]
    return issues
end

def filter_worklogs(issues, print_issues, date_start, date_end)

    total_time = 0

    issues.each do |issue|
        if issue["fields"]["worklog"]["worklogs"].nil?
            next
        end
        issue["fields"]["worklog"]["worklogs"].each do |worklog|
            if worklog["author"]["emailAddress"] != $user and worklog["author"]["name"] != $user
                next
            end

            date = parse_date(worklog["started"])
            if date < date_start or date > date_end
                next
            end

            total_time += worklog["timeSpentSeconds"]
            if print_issues
                puts "#{issue["key"]} - [#{worklog["timeSpent"]}] - #{issue["fields"]["summary"]} - #{date_to_str(date)}"
            end
        end
    end

    hours = total_time / 3600
    return hours
end

issues = load_issues()
today_date_midnight_in_utc = Date.today.to_datetime - Time.now.utc_offset / (60 * 60 * 24.0)
today_date_midnight = today_date_midnight_in_utc.new_offset(Time.now.utc_offset / (60 * 60 * 24.0))

today_date_morning = today_date_midnight + $morning_hour/24.0

today_hours = filter_worklogs(issues, true, today_date_morning, today_date_morning.next_day())
puts
print "today: ".light_blue, "#{today_date_morning.strftime("%d-%m-%Y")} ", hours_to_str(today_hours)
puts
puts

#change till number here to print many previous days
for i in 1..30
    from = today_date_morning.next_day(-i)
    till = today_date_morning.next_day(-i + 1)
    hours = filter_worklogs(issues, false, from, till)
    if hours > 0
        print "#{from.strftime("%d-%m-%Y")} ", hours_to_str(hours)
        puts
    end
end

puts

month_date_start = today_date_midnight - Date.today.mday + 1
month_date_end = month_date_start + get_number_of_days(month_date_start)
month_hours = filter_worklogs(issues, false, month_date_start, month_date_end)
print "month ".magenta, hours_to_str(month_hours)
puts

prev_month_date_end = month_date_start
prev_month_date_start = month_date_start - get_number_of_days(prev_month_date_end - 1)
prev_month_hours = filter_worklogs(issues, false, prev_month_date_start, prev_month_date_end)
print "prev month ".magenta, hours_to_str(prev_month_hours)
puts
puts


infinite_early_date = today_date_midnight - 50 * 365
infinite_late_date = today_date_midnight + 50 * 365
total_hours = filter_worklogs(issues, false, infinite_early_date, infinite_late_date)
print "overall ".cyan, hours_to_str(total_hours)
puts
puts
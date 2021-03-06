require 'curb'
require 'json'
require 'date'
require 'colorize'

$url = ARGV[0]
$user = ARGV[1]
$password = ARGV[2]
$morning_hour = 9
$number_of_previous_days_to_print = 3

$custom_date_range_from = ARGV.count > 3 ? ARGV[3] : nil
$custom_date_range_till = ARGV.count > 4 ? ARGV[4] : nil

if ARGV.count != 3 and ARGV.count != 5
    puts 'wrong number of parameters'.red
    puts 'USAGE:'.green
    puts 'ruby jira.rb http://yourjira.atlassian.net your@gmail.com yourpassword'
    puts 'OR:'.green
    puts 'ruby jira.rb http://yourjira.atlassian.net your@gmail.com yourpassword 04-09-2018 04-10-2018'
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
    result_issues = []

    start = 0
    loop do
        result = load_issues_with_start(start)
        issues = result["issues"]

        startAt = result["startAt"]
        maxResults = result["maxResults"]
        total = result["total"]
        result_issues += issues

        start = startAt + issues.count
        if start >= total
            break
        end
    end

    return result_issues
end

def load_issues_with_start(start)
    request = {
        "jql": "worklogAuthor = currentUser()",
        "startAt": start,
        "maxResults": 100,
        "fields": [
            "project",
            "summary",
            "status",
            "assignee",
            "worklog"
        ]
    }


    c = Curl::Easy.http_post("#{$url}/rest/api/2/search", request.to_json)
    # puts "#{$url}/rest/api/2/search"
    # puts request.to_json

    c.http_auth_types = :basic
    c.headers["Content-Type"] = "application/json"
    c.username = $user
    c.password = $password
    c.verbose = false
    c.perform
    result =  JSON.parse(c.body_str)

    return result
end

def filter_worklogs(issues, print_issues, date_start, date_end)

    total_time = 0

    hours_cache = {}

    issues.each do |issue|
        if issue["fields"].nil? or issue["fields"]["worklog"].nil? or issue["fields"]["worklog"]["worklogs"].nil?
            next
        end

        if issue["fields"]["worklog"]["total"] > issue["fields"]["worklog"]["maxResults"]
            print "Number of worklogs limit exceeded in task: #{issue["key"]} (#{issue["fields"]["worklog"]["total"]})".red
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

            key = issue["key"]
            if hours_cache[key].nil? 
                hours_cache[key] = 0
            end
            hours_cache[key] += worklog["timeSpentSeconds"]

            if print_issues
                puts "#{key} - [#{worklog["timeSpent"]}] - #{issue["fields"]["summary"]} - #{date_to_str(date)}"
            end
        end
    end


    if print_issues
        puts "Hours by issues:"
        hours_cache.keys.sort.each do |key|
            puts "[#{key}]-----#{hours_cache[key]/3600}h"
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

for i in 1..$number_of_previous_days_to_print
    from = today_date_morning.next_day(-i)
    till = today_date_morning.next_day(-i + 1)
    hours = filter_worklogs(issues, i == 1, from, till)
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

if not $custom_date_range_from.nil? and not $custom_date_range_till.nil?
    custom_date_start = Date.parse($custom_date_range_from)
    custom_date_end = Date.parse($custom_date_range_till)
    custom_date_hours = filter_worklogs(issues, true, custom_date_start, custom_date_end)
    print "custom range ".magenta, "#{custom_date_start.strftime("%d-%m-%Y")} –– #{custom_date_end.strftime("%d-%m-%Y")} ".yellow, hours_to_str(custom_date_hours)
    puts
    puts
end


infinite_early_date = today_date_midnight - 50 * 365
infinite_late_date = today_date_midnight + 50 * 365
total_hours = filter_worklogs(issues, false, infinite_early_date, infinite_late_date)
print "overall ".cyan, hours_to_str(total_hours)
puts
puts

puts

# date_start = Date.parse('28-01-2018')
# date_end = Date.today + 1
# hours = filter_worklogs(issues, true, date_start, date_end)
# print "month ".magenta, hours_to_str(hours)
# puts
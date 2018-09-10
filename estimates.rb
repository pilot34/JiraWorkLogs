require 'curb'
require 'json'
require 'date'
require 'command_line_reporter'

class Report
    include CommandLineReporter

    def initialize(issues)
        @issues = issues
    end   

    def run
        header(title: 'Estimates', align: 'center', width: 70)

        table border: true  do
            row header: true, color: 'blue', bold: true do
                column 'Key', width: 7, align: 'center'
                column 'Spent', width: 6, align: 'right'
                column 'Est.', width: 6, align: 'right'
                column 'Ratio', width: 6, align: 'right'
                column 'URL', width: 45
            end
            @issues.each do |issue|
                f = issue["fields"]
                ratio = f["workratio"]
                if ratio > 300
                    color = "red"
                elsif ratio > 200
                    color = "yellow"
                elsif ratio > 100   
                    color = "cyan"
                else
                    color = "green"
                end

                row color: color do
                    column issue["key"]
                    column seconds_to_str(f["timespent"])
                    column seconds_to_str(f["timeoriginalestimate"])
                    column ratio, align: 'right'
                    column "#{$url}/browse/#{issue["key"]}"
                end
            end
        end

        vertical_spacing 1
    end
end

$url = ARGV[0]
$user = ARGV[1]
$password = ARGV[2]

if ARGV.count != 3
    puts 'wrong number of parameters'
    puts 'USAGE:'
    puts 'ruby esimates.rb http://yourjira.atlassian.net your@gmail.com yourpassword'
    exit(0)
end

def date_to_str(date)
    return date.strftime("%d-%m-%Y %H:%M")
end

def seconds_to_str(seconds)
    hours = seconds / 3600
    return hours.to_s
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
            "worklog",
            "workratio",
            "timespent",
            "timeestimate",
            "timeoriginalestimate"
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

    return result
end

issues = load_issues().select do |issue| 
    f = issue["fields"]
    !f.nil? && !f["timespent"].nil? \
     && !f["timeoriginalestimate"].nil? \
     && !f["workratio"].nil? \
     && f["timespent"] > 0 \
     && f["timeoriginalestimate"] > 0
end
issues = issues.sort_by { |issue| issue["fields"]["workratio"]}.reverse
Report.new(issues).run
# JiraWorkLogs

## jira.rb
Ruby script to load work logs from Jira Cloud through the API without a paid Tempo plugin (total logged time in the time tracking section)

Run 
```bash
ruby jira.rb https://yourjira.atlassian.net yourmail@gmail.com yourpassword
``` 
or
```bash
ruby jira.rb https://yourjiradomain.com yourusername yourpassword
``` 

to see your today, yesterday, month and overall work log.

You should install some gems before that:
```bash
gem install json curb colorize
```


Output:

![](https://monosnap.com/file/QrNuPDbTyITfGqDKwNfKH74wCFMpPW.png)

```bash
today: 01-02-2017 0 hours

31-01-2017 total hours: 10 hours
30-01-2017 total hours: 9 hours
29-01-2017 total hours: 3 hours

month 0 hours
prev month 138 hours

overall 175 hours
```


## estimates.rb
Ruby script to analyze your time estimation quality. Gives you a list of issues with a spent time, an estimate and their ratio in percents.

Run
```bash
ruby estimates.rb https://yourjira.atlassian.net yourmail@gmail.com yourpassword
``` 
or
```bash
ruby estimates.rb https://yourjiradomain.com yourusername yourpassword
``` 

You should install some gems before that:
```bash
gem install json curb command_line_reporter
```

Output:

![](https://preview.ibb.co/db2Vh9/Screen_Shot_2018_09_10_at_23_31_10.png)

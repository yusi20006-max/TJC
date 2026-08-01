# TJC Scheduler System

The TJC Scheduler allows you to schedule workflows to run automatically at specific intervals without needing a continuous, battery-draining background daemon. It is highly optimized for Linux environments and Termux on Android.

## Schedule Expressions / Intervals

You can schedule workflows to execute at the following built-in intervals or at any positive integer representing minutes:

- **`every_minute`** (or `1`): Runs once every minute.
- **`every_5_minutes`** (or `5`): Runs once every 5 minutes.
- **`every_10_minutes`** (or `10`): Runs once every 10 minutes.
- **`every_30_minutes`** (or `30`): Runs once every 30 minutes.
- **`hourly`** (or `60`): Runs once every hour.
- **`daily`** (or `1440`): Runs once every 24 hours (daily).
- **`<integer>`**: Any custom interval in minutes (e.g. `120` for every 2 hours).

## CLI Usage

### 1. Register/Add a Schedule
Add a scheduled job to run a workflow:
```sh
tjc schedule add daily_review /path/to/my-workflow.yml daily
```

### 2. List Configured Schedules
See active schedules along with their interval, last run, and last status:
```sh
tjc schedule list
```

### 3. Remove a Schedule
Unschedule a job:
```sh
tjc schedule remove daily_review
```

### 4. Manually Run a Schedule Immediately
Run a specific schedule immediately regardless of the scheduled interval:
```sh
tjc schedule run daily_review
```
Or run all configured schedules immediately:
```sh
tjc schedule run
```

### 5. Automatic Execution (Run Pending Jobs)
Runs any scheduled workflows whose intervals have elapsed since their last execution:
```sh
tjc schedule run-pending
```

### 6. Display Job Execution History
Show a detailed log list of past executions for a schedule:
```sh
tjc schedule history daily_review
```

## Linux / Termux Integration

To run schedules automatically, simply integrate the `run-pending` command with standard task managers.

### 1. Standard Crontab (Linux)
Add the following line to your crontab to run pending jobs every minute:
```cron
* * * * * /usr/local/bin/tjc schedule run-pending >/dev/null 2>&1
```

### 2. Termux / Android Integration (Termux:Boot or Cron)
Since Android does not run a standard system cron daemon by default, you can utilize the `termux-cron` package:
1. Install standard cron package in Termux:
   ```sh
   pkg install cronie
   ```
2. Schedule the pending check:
   ```sh
   crontab -e
   ```
   Add:
   ```cron
   * * * * * tjc schedule run-pending >/dev/null 2>&1
   ```
3. Start the cron daemon at boot or manually:
   ```sh
   crond
   ```

Schedules are persistently and securely stored as JSON configurations under `~/.config/tjc/schedules/`.

## Practical Scheduler Setup Example

Let's walk through registering and automating a daily health-check workflow.

### Step 1: Create your workflow file
Save the following as `/home/user/workflows/daily-health.yml`:

```yaml
name: "Daily Health Check Workflow"
description: "Checks dependencies and prints recent Jules activities"
steps:
  - type: doctor
  - type: list_activities
```

### Step 2: Register the workflow with the TJC Scheduler
We will name this schedule `daily_health_check` and set it to run every 1440 minutes (once a day):

```sh
tjc schedule add daily_health_check /home/user/workflows/daily-health.yml 1440
```

### Step 3: Verify the schedule registration
List configured schedules:

```sh
tjc schedule list
```

Example Output:
```
Active Schedules:
ID              WORKFLOW FILE                  INTERVAL        LAST RUN             LAST STATUS
--------------------------------------------------------------------------------------------------
daily_health_check daily-health.yml           1440            Never                Never
```

### Step 4: Automate Execution (Pull-Model)
The TJC Scheduler is designed to avoid background daemons. Instead, it relies on a `run-pending` command. You can set this to execute every minute via system `cron`.

Open your crontab configuration:
```sh
crontab -e
```

Add the following cron expression to check for due scheduled workflows every minute:
```cron
* * * * * /usr/local/bin/tjc schedule run-pending >> /var/log/tjc_cron.log 2>&1
```

If the interval of `1440` minutes (since the last run or since creation) has elapsed, TJC will run the workflow automatically on the next minute check.

### Step 5: Review Execution History
To view the status and past timestamps of the scheduled executions:

```sh
tjc schedule history daily_health_check
```

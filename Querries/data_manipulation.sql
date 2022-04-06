USE [Fitness Tracker];

-- Reformat the ActivityDate column so that it has the same format as the other datetime columns
SELECT 
	* , 
	FORMAT(ActivityDate, 'yyyy-MM-dd 00:00:00.000') AS [Date]
INTO daily_activity_temp
FROM daily_activity;

-- Drop the ActivityDate column, since it now contains repeated information
ALTER TABLE daily_activity_temp
DROP COLUMN ActivityDate;

-- Query the results to save it to a csv file
SELECT * FROM daily_activity_temp;

-- =========================================================== --
-- Alter the weight_log_info table to include more information --
-- =========================================================== --
ALTER TABLE weight_log_info
ADD 
	Number_of_Logs SMALLINT, -- Add a column for the number of logs each user inputs
	WeightLoss_pounds FLOAT; -- Add a column for the weight loss of each person in between each weigh-in
-- Remove irrelevant information
ALTER TABLE weight_log_info
DROP COLUMN 
	WeightKg,        -- Repeated information from WeightPounds
	Fat,             -- Most users don't enter this information
	LogId;           -- Doesn't tell us anything about the user's health status

-- Populate the weight loss column
WITH weight_track AS (
SELECT
	-- Id and Date are used to determine where to insert the weight log information
	Id,
	[Date],
	-- Calculate how much weight each user has lost on each weight log
	---- Note that a positive value represents a weight gain
	WeightPounds - LAG(WeightPounds) OVER(PARTITION BY Id ORDER BY [Date]) AS WeightLossPounds,
	-- Calculate how many times each person logged their weight
	COUNT(*) OVER(PARTITION BY Id) AS Log_num
FROM weight_log_info
)
-- Insert the weight loss information into the weight_log_info table
UPDATE weight_log_info
SET 
	weight_log_info.WeightLoss_pounds = weight_track.WeightLossPounds,
	weight_log_info.Number_of_Logs = weight_track.Log_num
FROM weight_log_info
INNER JOIN weight_track
ON weight_log_info.Id = weight_track.Id AND weight_log_info.[Date] = weight_track.[Date]

-- Check the results
SELECT * 
FROM weight_log_info
ORDER BY
	Number_of_Logs DESC,
	Id,
	[Date];

-- Split the Date from the time for joining this table to other information
ALTER TABLE weight_log_info
ADD [Time] TIME;
UPDATE weight_log_info
SET 
	[Time] = FORMAT([Date], 'HH:mm:ss'),
	[Date] = FORMAT([Date], 'yyyy-MM-dd');

-- Check the results
SELECT * 
FROM weight_log_info
ORDER BY
	Number_of_Logs DESC,
	Id,
	[Date];

/*
It is of interest to note that there are a significant number of weight_log entries at 23:59:59
This leads me to believe that this is a missing value.
Through further inspection, it seems as though the time is 23:59:59 when the user has manually entered their weight,
which further strengthens the hypothesis that this time represents a missing value
*/
UPDATE weight_log_info
SET [Time] = NULL
WHERE IsManualReport = 1;

-- Check the results
SELECT * 
FROM weight_log_info
ORDER BY
	Number_of_Logs DESC,
	Id,
	[Date];
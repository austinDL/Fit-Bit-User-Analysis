USE [Fitness Tracker];

-- Display the data we are working with
---- Note: we do not need daily or hourly data, since this can be determined through aggregates
SELECT TOP 1 'daily_activity'     AS table_name, * FROM daily_activity;
SELECT TOP 1 'minute_calories'    AS table_name, * FROM minute_calories;
SELECT TOP 1 'minute_intensities' AS table_name, * FROM minute_intensities;
SELECT TOP 1 'minute_METs'        AS table_name, * FROM minute_METs;
SELECT TOP 1 'minute_sleep'       AS table_name, * FROM minute_sleep;
SELECT TOP 1 'minute_steps'       AS table_name, * FROM minute_steps;
SELECT TOP 1 'heartRate_seconds'  AS table_name, * FROM heartRate_seconds;
SELECT TOP 1 'weight_log_info'    AS table_name, * FROM weight_log_info;

-- Create a table that joins all the minute data together
CREATE TABLE dbo.all_minute_data(
	ID BIGINT,
	[Date] DATETIME,
	Calories FLOAT,
	Intensity SMALLINT,
	METs SMALLINT,
	Sleep_Score SMALLINT,
	Num_of_Steps SMALLINT,
	HeartRate FLOAT
);
-- Create a heartRate CTE that aggregates the data by the minute
WITH minute_heartRate AS (
	SELECT 
		Id AS ID,
		FORMAT([Time], 'yyyy-MM-dd hh:mm:00.000') AS [Date],
		AVG([Value]) AS heartRate
	FROM heartRate_seconds
	GROUP BY ID, FORMAT([Time], 'yyyy-MM-dd hh:mm:00.000')
)
-- Insert the merged query results into the all_minute_data table created above
INSERT INTO dbo.all_minute_data
	SELECT 
		cal.Id AS ID, 
		cal.ActivityMinute AS [Date], 
		cal.Calories,
		intensity.Intensity,
		met.METs,
		sleep.[value] AS Sleep_Score,
		steps.Steps AS Num_of_Steps,
		heartRate.heartRate AS HeartRate
	FROM minute_calories AS cal
	-- Join all the data such that each row is unique for a user at a given time
	-- We use a full join, since we want all data even if there aren't matching values
	FULL JOIN minute_intensities AS intensity 
		ON intensity.Id = cal.Id AND intensity.ActivityMinute = cal.ActivityMinute
	FULL JOIN minute_METs AS met 
		ON met.Id = cal.Id AND met.ActivityMinute = cal.ActivityMinute
	FULL JOIN minute_sleep AS sleep 
		-- Sleep data is not always recorded on the minute, so we need to round to the nearest minute to join the tables
		ON sleep.Id = cal.Id AND FORMAT(sleep.[date], 'yyyy-MM-dd hh:mm:00.000') = cal.ActivityMinute
	FULL JOIN minute_steps AS steps 
		ON steps.Id = cal.Id AND steps.ActivityMinute = cal.ActivityMinute
	FULL JOIN minute_heartRate AS heartRate 
		ON heartRate.Id = cal.Id AND heartRate.[Date] = cal.ActivityMinute

-- Delete the rows will NULL ID values
DELETE FROM dbo.all_minute_data WHERE ID IS NULL;

-- Check the resulting table and save it to a csv file
USE [Fitness Tracker];
SELECT * FROM all_minute_data
ORDER BY ID, [Date];
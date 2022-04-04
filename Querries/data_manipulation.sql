USE [Fitness Tracker];

-- Modify the weight log data to include how often each user logged their weight and how much weight they lost between each log
SELECT
	Id, [Date], WeightPounds, BMI,
	COUNT(*) OVER(PARTITION BY Id) log_count,
	-- Calculate how much weight each user has lost on each weight log
	-- Note that a positive value represents a weight gain
	WeightPounds - LAG(WeightPounds) OVER(PARTITION BY Id ORDER BY [Date]) AS WeightLossPounds
FROM weight_log_info
-- Order the weight logs by how frequently the users logged their weight
-- Fewer weight logs makes it harder to notice a trend
ORDER BY log_count DESC, Id, [Date];


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
USE [Fitness Tracker];

--- Looking at the data
SELECT TOP 5 * FROM daily_activity;
SELECT TOP 5 * FROM all_minute_data;
SELECT TOP 5 * FROM weight_log_info;

-- ================================================================= --
-- Evaluate how users' activity changes between the days of the week --
-- ================================================================= --
-- Get the user activity for each day of the week
SELECT 
	-- Extract the day of the week to conduct an aggregate
	DATENAME(weekday, ActivityDate) AS 'Day of Week',
	DATEPART(weekday, ActivityDate) AS day_num,
	-- Aggregate the data by day of the week
	AVG(VeryActiveDistance)                        AS 'Very Active Distance',
	AVG(ModeratelyActiveDistance)                  AS 'Moderately Active Distance',
	AVG(LightActiveDistance)                       AS 'Lightly Active Distance',   -- Rename to maintain consistency
	AVG(CAST(VeryActiveMinutes AS FLOAT))          AS 'Very Active Minutes',
	AVG(CAST(FairlyActiveMinutes AS FLOAT))        AS 'Moderately Active Minutes', -- Rename to maintain consistency
	AVG(CAST(LightlyActiveMinutes AS FLOAT))       AS 'Lightly Active Minutes'
FROM daily_activity
GROUP BY DATENAME(weekday, ActivityDate), DATEPART(weekday, ActivityDate)
-- Order the data by the day of the week
ORDER BY day_num;

-- ============================================= --
-- Evaluate the affect of sleep on user activity --
-- ============================================= --
-- Create a function to calculate the rate of change
---- This function will handle the scenarios when the rate of change happens over 0 time, causing a divide by 0 error
ALTER FUNCTION GetRateOfChange(@time INT, @val FLOAT)
RETURNS FLOAT
AS
BEGIN
	DECLARE @RoC FLOAT
	IF (@time > 0)
		SET @RoC = @val / @time
	ELSE
		SET @RoC = NULL
	RETURN @RoC
END;


WITH 
-- Aggregate the sleep data to daily data
daily_sleep AS (
	SELECT 
		Id,
		FORMAT([date], 'yyyy-MM-dd') AS ActivityDate,
		AVG(CAST([value] AS FLOAT)) AS DailySleepScore -- Cast to float to get a floating point average
	FROM minute_sleep
	WHERE [value] IS NOT NULL
	GROUP BY Id, FORMAT([date], 'yyyy-MM-dd')
),
-- Add a column of Total Active Time to the daily_activity table
daily_activity_CTE AS (
	SELECT *,
		-- We need to cast the columns to BIGINT values to avoid TINYINT overflow problems
		CAST(VeryActiveMinutes AS BIGINT) 
		+ CAST(LightlyActiveMinutes AS BIGINT) 
		+ CAST(FairlyActiveMinutes AS BIGINT) ActivityTime
	FROM daily_activity
)
SELECT 
	DA.ActivityDate AS [Date],
	DA.TotalDistance AS 'Distance [km]',
	DA.ActivityTime AS 'Activity Time [mins]',
	DA.TotalSteps AS Steps,
	DA.Calories AS Calories,
	DS.DailySleepScore AS SleepScore,
	-- Calculate the average speeds for the different activity levels
	---- Note: we multiply by 60 to convert from km/min to km/hr
	dbo.GetRateOfChange(DA.VeryActiveMinutes, DA.VeryActiveDistance)*60
		AS 'Very Active Speed [km/hr]',
	dbo.GetRateOfChange(DA.FairlyActiveMinutes, DA.ModeratelyActiveDistance)*60
		AS 'Moderately Active Speed [km/hr]',
	dbo.GetRateOfChange(DA.LightlyActiveMinutes, DA.LightActiveDistance)*60
		AS 'Lightly Active Speed [km/hr]'
FROM daily_activity_CTE AS DA
JOIN daily_sleep AS DS
	ON DS.ActivityDate = DA.ActivityDate AND DS.Id = DA.Id


-- ============================================= --
-- Evaluate users' activity in between weigh-ins --
-- ============================================= --

-- Include the previous weight log date to determine the activity between weigh-ins
WITH weight_log AS (
	SELECT
		Id,
		Number_of_Logs,
		CAST([Date] AS DATE) WeighIn,
		CAST(
			LAG([Date]) OVER(PARTITION BY Id ORDER BY [Date]) AS DATE
		) AS Previous_WeighIn,
		WeightLoss_pounds
	FROM weight_log_info
)
SELECT 
	Id,
	WeighIn [Date],
	WeightLoss_pounds/DATEDIFF(DAY, Previous_WeighIn, WeighIn) 'Daily Weight Loss [lbs]',
	(
		SELECT SUM(Calories) / DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM daily_activity da
		WHERE 
			da.ActivityDate BETWEEN Previous_WeighIn AND WeighIn
			AND da.Id = weight_log.Id
	) AS DailyCaloriesLost,
	(
		SELECT SUM(TotalSteps) / DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM daily_activity da
		WHERE 
			da.ActivityDate BETWEEN Previous_WeighIn AND WeighIn
			AND da.Id = weight_log.Id
	) AS DailySteps,
	(
		SELECT SUM(TotalDistance) / DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM daily_activity da
		WHERE 
			da.ActivityDate BETWEEN Previous_WeighIn AND WeighIn
			AND da.Id = weight_log.Id
	) AS DailyDistanceTravelled,
	(
		SELECT (SUM(VeryActiveMinutes) + SUM(FairlyActiveMinutes) + SUM(LightlyActiveMinutes))/ DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM daily_activity da
		WHERE 
			da.ActivityDate BETWEEN Previous_WeighIn AND WeighIn
			AND da.Id = weight_log.Id
	) AS DailyActivityTime,
	-- The remaining queries aim to acquire the users' intensity
	(
		SELECT AVG(Intensity)/ DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM all_minute_data md
		WHERE 
			md.[Date] BETWEEN Previous_WeighIn AND WeighIn
			AND md.ID = weight_log.Id
			AND md.Intensity > 0 -- We only care about when the user is active
	) AS AverageDailyIntensity,
	(
		SELECT AVG(METs)/ DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM all_minute_data md
		WHERE 
			md.[Date] BETWEEN Previous_WeighIn AND WeighIn
			AND md.ID = weight_log.Id
	) AS AverageDailyMETs,
	(
		SELECT AVG(HeartRate)/ DATEDIFF(DAY, Previous_WeighIn, WeighIn)
		FROM all_minute_data md
		WHERE 
			md.[Date] BETWEEN Previous_WeighIn AND WeighIn
			AND md.ID = weight_log.Id
	) AS AverageDailyHeartRate
FROM weight_log
-- We need atleast 2 data points to determine a trend (3 data points gives us 2 data points for weight loss)
WHERE Number_of_Logs > 2
ORDER BY Number_of_Logs DESC, Id, WeighIn;

SELECT Intensity FROM all_minute_data WHERE Intensity > 0;
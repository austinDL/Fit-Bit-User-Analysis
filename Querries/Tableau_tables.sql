USE [Fitness Tracker];

SELECT * FROM daily_activity;

-- Get the user activity for each day of the week
SELECT 
	DATENAME(weekday, ActivityDate) AS 'Day of Week',
	DATEPART(weekday, ActivityDate) AS day_num,
	AVG(VeryActiveDistance)         AS 'Very Active Distance',
	AVG(ModeratelyActiveDistance)   AS 'Moderately Active Distance',
	AVG(LightActiveDistance)        AS 'Lightly Active Distance',   -- Rename to maintain consistency
	AVG(VeryActiveMinutes)          AS 'Very Active Minutes',
	AVG(FairlyActiveMinutes)        AS 'Moderately Active Minutes', -- Rename to maintain consistency
	AVG(LightlyActiveMinutes)       AS 'Lightly Active Minutes'
FROM daily_activity
GROUP BY DATENAME(weekday, ActivityDate), DATEPART(weekday, ActivityDate)
ORDER BY day_num;
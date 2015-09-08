--this is full version to find every month ever. By limiting it again in places indicated (search for word 'limiting') we can speed it up. It's complex but takes no longer than 30min at present

--Constraints
--Individuals only. But NOT limited to 'IGE' regular gifts.


--10 regular giving calculation
--I tried using CTEs for this, but there's just too much data even though there was no index suggestion. Temp tables coped fine in a very tiny fraction of the time CTE approach took.

--All regular gifts with the months they were either given or amended - takes 35 seconds alone with limiter
select LatestSequence.*,pt.PaymentType,Amounts.AnnualisedAmount
into #RegularGiftDetails
from
(
select distinct ConstituentID,r.GiftFactID_of_the_RG,d.CalendarYearMonth, MAX(r.sequence) as LatestSequence
from VIEW_RG_History r
inner join DIM_Date d on d.DateDimID = r.[DatedimID of gift or amendment]
group by ConstituentID,r.GiftFactID_of_the_RG,d.CalendarYearMonth
) LatestSequence
inner join 
(
select GiftFactID_of_the_RG,Sequence,AnnualisedAmount
from VIEW_RG_History
) Amounts 
on Amounts.GiftFactID_of_the_RG = LatestSequence.GiftFactID_of_the_RG
and Amounts.Sequence = LatestSequence.LatestSequence
inner join FACT_Gift on latestsequence.GiftFactID_of_the_RG = FACT_Gift.GiftFactID
inner join DIM_PaymentType PT on PT.PaymentTypeDimID = fact_gift.PaymentTypeDimID
;
--All regular gifts crossed with every single relevant month since that gift began (including first month)
--Commented out limiter to months from specific month can save time
--takes 105 seconds alone with limiter
select distinct GiftFactID_of_the_RG, CalendarYearMonth as EveryRelevantMonth
into #EveryMonthGiftMayHaveExisted
from 
(
select GiftFactID_of_the_RG, MIN(calendaryearmonth) as GiftStartMonth
from
VIEW_RG_History inner join DIM_Date on DIM_Date.DateDimID = VIEW_RG_History.[DatedimID of gift or amendment]
group by GiftFactID_of_the_RG
) r inner join 
DIM_Date d on d.CalendarYearMonth >= r.GiftStartMonth
--where d.CalendarYearMonth >201303 --just limiting for speed
and CalendarYearMonth < (select top 1 CalendarYearMonth from DIM_Date where IsCurrentMonth = 1)
;

--combining into main regular giving list by constituent and gift
select 
r.ConstituentID,
m.GiftFactID_of_the_RG,
EveryRelevantMonth as CalendarYearMonth,
r.PaymentType,
r.AnnualisedAmount as AnnualAmountAtEndThisMonth,
r.LatestSequence as LatestSequence
into #RegularGivingResultsBeforeRemovingOutdatedAmendments
from #EveryMonthGiftMayHaveExisted m
inner join #RegularGiftDetails r 
on r.GiftFactID_of_the_RG = m.GiftFactID_of_the_RG 
and r.CalendarYearMonth <= m.EveryRelevantMonth
--this join is all cancellation months so that those are not included in the list
left outer join 
(
select
GiftFactID,
case 
--next line treats all cancelled where not yet in imported gift status date table from RE as having cancelled in the CURRENT month!
when s.[Gift Status Date] IS null and s.[System Record ID] IS null then (select top 1 calendaryearmonth from DIM_Date where IsCurrentMonth	= 1)
--next line deals with 'null' where they ARE in the imported gift status date table from RE, and assumes they are all long in the past. Issue re-raised of getting these corrected on RE (and noted as issue on github)
--I believe in practice they do all go back to 2005 or earlier...
when s.[Gift Status Date] is null then 197912 else CalendarYearMonth end as MonthCancelled
from
A_GM_GiftStatusDate s 
right outer join FACT_Gift g on g.GiftSystemID = s.[System Record ID]
inner join DIM_GiftStatus gs on gs.GiftStatusDimID = g.GiftStatusDimID--
left outer join DIM_Date d on d.ActualDate = s.[Gift Status Date]
where gs.GiftStatus in ('Terminated','Cancelled','Completed')
) Cancellations 
on Cancellations.GiftFactID = r.GiftFactID_of_the_RG
where 
Cancellations.MonthCancelled is null --i.e. still active now
or EveryRelevantMonth < Cancellations.MonthCancelled --i.e. had been cancelled during or since that month

;
--further work to only keep the highest sequence number for each person, for each month
--before this, both the old and new annualised value would show for all with amendments
select * 
into #RegularGivingResults
from #RegularGivingResultsBeforeRemovingOutdatedAmendments
except
select t1.ConstituentID,t1.GiftFactID_of_the_RG,t1.CalendarYearMonth,t1.PaymentType,t1.AnnualAmountAtEndThisMonth,t1.LatestSequence
from #RegularGivingResultsBeforeRemovingOutdatedAmendments t1 
inner join #RegularGivingResultsBeforeRemovingOutdatedAmendments t2
on t1.ConstituentID = t2.ConstituentID 
and t1.CalendarYearMonth = t2.CalendarYearMonth
and t1.GiftFactID_of_the_RG = t2.GiftFactID_of_the_RG
and t1.LatestSequence < t2.LatestSequence
;
--this is additional bit to start being able to look back at retention rates and similar, it populates A_GM_Dashboards_RGRetentionByMandateStart
select
ConstituentID,
Giftfactid,
GiftStatus,
MonthMandateSetUp,
case when GiftStatus = 'Active' then NULL else MonthDuringWhichStatusChanged end as MonthDuringWhichCancelled,
FinalMonthGiftWasActiveAtEndOf
into #GiftDateInfo
from
(
select 
MainSub.*,
case when
GiftStatus = 'Active' then null
else
everymonth.CalendarYearMonth end as FinalMonthGiftWasActiveAtEndOf -- Is null for 12k cancelled old gifts without known status dates
from
(
select 
ConstituentID,
GiftFactID,
dategift.CalendarYearMonth as MonthMandateSetUp,
gs.GiftStatus,
datestatuschanged.CalendarYearMonth as MonthDuringWhichStatusChanged,
datestatuschanged.MonthsSince as MonthsSinceStatusChanged
from
fact_gift g
left outer join DIM_Date dategift on dategift.ActualDate = g.GiftDate
inner join DIM_Constituent c on c.ConstituentDimID = g.ConstituentDimID
inner join DIM_GiftStatus gs on gs.GiftStatusDimID = g.GiftStatusDimID
left outer join A_GM_giftstatusdate s 
left outer join DIM_Date datestatuschanged on datestatuschanged.ActualDate = s.[Gift Status Date]
on s.[System Record ID] = g.GiftSystemID
where GiftTypeDimID = 30
--order by GiftFactID,[Gift Status Date] desc,giftdate desc
) MainSub
left outer join
(select distinct calendaryearmonth,monthssince from DIM_Date) everymonth
on everymonth.MonthsSince = MainSub.MonthsSinceStatusChanged +1
) SubToBringTogether



--put facts into a long table for each month
SELECT 
--r.ConstituentID,
--r.GiftFactID_of_the_RG,
r.CalendarYearMonth,
r.PaymentType,
g.MonthMandateSetUp,
g.MonthDuringWhichCancelled,
COUNT(distinct r.ConstituentID) as Constituents, --this distinct makes it take a lot longer (but is useful since there are fewer constituents than gifts)
COUNT(r.GiftFactID_of_the_RG) as Gifts,
SUM(r.AnnualAmountAtEndThisMonth) as AnnualAmountAtEndThisMonth
into #RetentionLongTable
FROM
#RegularGivingResults r
full outer join 
#GiftDateInfo g
on g.GiftFactID = r.GiftFactID_of_the_RG
group by 
--r.ConstituentID,
--r.GiftFactID_of_the_RG,
r.CalendarYearMonth,
r.PaymentType,
g.MonthMandateSetUp,
g.MonthDuringWhichCancelled
order by AnnualAmountAtEndThisMonth desc
;

--populate A_GM_Dashboards_RGRetentionByMandateStart
delete from A_GM_Dashboards_RGRetentionByMandateStart
;
insert into A_GM_Dashboards_RGRetentionByMandateStart
select
CalendarYearMonth,
PaymentType,
CancellationStatus,
NumberOfMonthsSinceMandateSetUp_CancelledOnly,
SUM (Constituents) as Constituents,
SUM (Gifts) as Gifts,
SUM (AnnualAmountAtEndThisMonth) as AnnualAmountAtEndThisMonth
from
(
select 
CalendarYearMonth,
PaymentType,
case 
when NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring <0 then null
when NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring is null then null
else NumberOfMonthsSinceMandateSetUp
end as NumberOfMonthsSinceMandateSetUp_CancelledOnly,
Case 
when NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring <0 then 'Cancelled in future'
when NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring =0 then 'Cancelled DURING this month'
when NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring is null then 'Still active now'
else 'Cancelled BEFORE this month'
end as CancellationStatus,
Constituents,
Gifts,
AnnualAmountAtEndThisMonth
from
(
select 
r.CalendarYearMonth,
r.PaymentType,
r.MonthMandateSetUp,
r.MonthDuringWhichCancelled,
r.Constituents,
r.Gifts,
r.AnnualAmountAtEndThisMonth,
case 
when dateofinterest.MonthsSince - datecancelled.MonthsSince <1 then 1 else 0 end as [CancelledByEndOfThisMonth?],
--dateofinterest.MonthsSince as MonthsSinceMonthLookingAt,
--datecancelled.MonthsSince as MonthsSinceCancellation,
datecancelled.MonthsSince - dateofinterest.MonthsSince as NumberOfMonthsPriorThatWasMonthGiftWasCancelledDuring,
dateofmandatesetup.MonthsSince - dateofinterest.monthssince  as NumberOfMonthsSinceMandateSetUp
from #RetentionLongTable r
left outer join (select distinct calendaryearmonth,monthssince from DIM_Date) datecancelled on datecancelled.CalendarYearMonth = r.MonthDuringWhichCancelled
left outer join (select distinct calendaryearmonth,monthssince from DIM_Date) dateofinterest on dateofinterest.CalendarYearMonth = r.CalendarYearMonth
left outer join (select distinct calendaryearmonth,monthssince from DIM_Date) dateofmandatesetup on dateofmandatesetup.CalendarYearMonth = r.MonthMandateSetUp
where 
--r.CalendarYearMonth = MonthDuringWhichCancelled
--and r.CalendarYearMonth - MonthDuringWhichCancelled >-1
r.CalendarYearMonth > 201003
--order by MonthDuringWhichCancelled desc, MonthMandateSetUp desc
) sub
) widersubtoputnoncancelledtogether
group by
CalendarYearMonth,
PaymentType,
CancellationStatus,
NumberOfMonthsSinceMandateSetUp_CancelledOnly

;

--20 cash calculation

with MonthLookup_CTE as
--this is based on file size AT END MONTH so includes only gifts from the 'next' month in order two years before and onwards
(
select distinct d1.calendaryearmonth,d2.CalendarYearMonth as EveryMonthWithin24 
from DIM_Date d1
inner join DIM_Date d2 
on d2.MonthsSince < (d1.MonthsSince + 24)
and d2.MonthsSince > (d1.MonthsSince - 1)
/* in case ever checking
where d1.CalendarYearMonth = 199601
order by EveryMonthWithin24
*/
)
,
AmountGiven_CTE as
(
select 
ConstituentID
--,MAX(giftdate) as LatestIndividualCashDate 
,d.CalendarYearMonth
,SUM(GiftAmount) as GivenInMonth
from a_GM_TBL_AllCashGifts G
inner join DIM_Date d on d.ActualDate = g.GiftDate
where [IsDMTOrMajorDonorCashGift?] = 'Yes'
group by ConstituentID,d.CalendarYearMonth
)


--this inner query shows us results for every individual person if ever useful
select ConstituentID,m.CalendarYearMonth,SUM(GivenInMonth) as CashGivenWithin24Mths, 'Not known yet' as GiverCategory
into #IndividualCashResults
from AmountGiven_CTE a
inner join MonthLookup_CTE m on m.EveryMonthWithin24 = a.CalendarYearMonth
--where constituentID = 533496 [checking]
where m.CalendarYearMonth < (select top 1 CalendarYearMonth from DIM_Date where IsCurrentMonth = 1)
--and m.CalendarYearMonth >201303 --just limiting results a bit for speed
group by ConstituentID,m.CalendarYearMonth 

;

--30 Populating a list of constituentIDs stating who was ActiveCoG only, Active CoG and ActiveCash, ActiveCash only each month, along with their values

select 
case 
when t2_ID IS null then t1_ID
when t1_ID is null then t2_ID
else t1_ID
end as ConstituentID,
case 
when t2.CalendarYearMonth IS null then t1.CalendarYearMonth
when t1.CalendarYearMonth is null then t2.CalendarYearMonth
else t1.CalendarYearMonth
end as CalendarYearMonth,
t1.RegularGivingTotal as RegularGivingAnnualValue,
t2.CashGivenDuringLast24Months,
case 
when RegularGivingTotal IS not null and CashGivenDuringLast24Months is not null then 'Active CoG and Active Cash'
when RegularGivingTotal is not null then 'Active CoG only'
when CashGivenDuringLast24Months IS not null then 'Active Cash only'
else 'HasntGivenInThePeriodWeAreLookingAt'
end as GiverCategory
into #StatusOfEachPersonEachMonth
from
(
select constituentID as t1_ID,Calendaryearmonth,SUM(AnnualAmountAtEndThisMonth) as RegularGivingTotal
from #RegularGivingResults r
group by constituentID,Calendaryearmonth
) t1
full outer join
(
select constituentID as t2_ID,Calendaryearmonth,SUM(c.CashGivenWithin24Mths) as CashGivenDuringLast24Months
from #IndividualCashResults c
group by constituentID,Calendaryearmonth
) t2 on t1.t1_ID = t2.t2_ID and t1.CalendarYearMonth = t2.CalendarYearMonth
;
delete from #StatusOfEachPersonEachMonth
where GiverCategory = 'HasntGivenInThePeriodWeAreLookingAt'
;
--remove ALL ORGANISATIONS since we are interested only in individuals for this purpose
delete from #StatusOfEachPersonEachMonth
where ConstituentID in
(
select distinct DIM_Constituent.ConstituentID from #StatusOfEachPersonEachMonth
inner join DIM_Constituent on DIM_Constituent.ConstituentID = #StatusOfEachPersonEachMonth.ConstituentID
where KeyIndicator = 'O'
)
--35 Changing status of people to 'Deceased...' where they became deceased as far as we know during or before the month in question
--Allows field to be longer so update can work - this way we keep track of who was deceased but would otherwise have counted
alter table #StatusOfEachPersonEachMonth
alter column GiverCategory varchar(41)
;

--this update takes only just over a minute!
update #StatusOfEachPersonEachMonth
set GiverCategory = 'Deceased - was '+ [All].GiverCategory
from
#StatusOfEachPersonEachMonth [All]
inner join
(
select s.* from #StatusOfEachPersonEachMonth s
inner join
(
select 
constituentID,
min(CalendarYearMonth) as MonthDeceased
from
(
select
ConstituentID, 
case when DeceasedDate is null then DateChanged else DeceasedDate end as BestDeceasedDateWeHave
from
(
select 
ConstituentID,DeceasedDate,DateChanged
from DIM_Constituent
where IsDeceased = 'Yes' and KeyIndicator = 'I'
) sub
) main inner join DIM_Date on DIM_Date.ActualDate > main.BestDeceasedDateWeHave and dim_date.DaysSince>0
group by ConstituentID
) d
on s.ConstituentID = d.ConstituentID
and s.CalendarYearMonth >= d.MonthDeceased 
) [DeceasedRows]
on [All].ConstituentID = [DeceasedRows].ConstituentID
and [All].CalendarYearMonth = [DeceasedRows].CalendarYearMonth
;

--40 Producing counts and sums of amounts for each month ever
--now stored as A_GM_Dashboards_FileSizeActuals
delete from A_GM_Dashboards_FileSizeActuals
;
insert into A_GM_Dashboards_FileSizeActuals
select
s.CalendarYearMonth,
s.GiverCategory,
COUNT(s.constituentID) as People,
sum (s.RegularGivingAnnualValue) as RegularGivingAnnualValue,
sum (s.CashGivenDuringLast24Months) as CashGivenTotalLastTwoYears
from
#StatusOfEachPersonEachMonth s
group by CalendarYearMonth,GiverCategory 
order by CalendarYearMonth,GiverCategory

;

--50 Working out amount given DURING EACH MONTH by people in each category at END that month
--now stored as A_GM_Dashboards_FileSizeCrossedGiving
--Could easily be limited by month to save time
--Individuals only
--Allows ANY regular giving payment, but cash are limited to the current 'DMT + MD' definition
delete from A_GM_Dashboards_FileSizeCrossedGiving
;
insert into A_GM_Dashboards_FileSizeCrossedGiving
select
GiverCategory,
GiftType,
CalendarYearMonth,
SUM(Total) as Total
from
(
select sub_giving.*,s.GiverCategory from 
(
select c.constituentID,calendaryearmonth,'Cash' as GiftType,sum(amount) as Total
from
FACT_Gift g
inner join DIM_Constituent c on c.ConstituentDimID = g.ConstituentDimID
inner join DIM_Date d on d.DateDimID = g.GiftDateDimID
inner join a_GM_TBL_AllCashGifts acg on acg.GiftFactID = g.GiftFactID
where 
GiftTypeDimID = 1
and c.KeyIndicator = 'I'
and [IsDMTOrMajorDonorCashGift?] = 'Yes' --so only these gifts...fact includes MD might need explaining!
group by c.constituentID,calendaryearmonth
union all
select constituentID,calendaryearmonth,'RG Payment' as GiftType,sum(amount) as Total
from
FACT_Gift g
inner join DIM_Constituent c on c.ConstituentDimID = g.ConstituentDimID
inner join DIM_Date d on d.DateDimID = g.GiftDateDimID
where 
GiftTypeDimID = 31
and c.KeyIndicator = 'I'
group by constituentID,calendaryearmonth
) sub_giving
left outer join 
#StatusOfEachPersonEachMonth s on s.ConstituentID = sub_giving.ConstituentID
and s.CalendarYearMonth = sub_giving.CalendarYearMonth
) sub_individualtotal
where CalendarYearMonth < (select MIN(CalendarYearMonth) from dim_date where monthssince = 0)
group by
GiverCategory,
GiftType,
CalendarYearMonth
order by CalendarYearMonth,GiverCategory,GiftType


/*
--checking area in case useful queries to have ready
select #StatusOfEachPersonEachMonth.ConstituentID,RegularGivingAnnualValue,AnnualValue_LargestActiveGift
from 
#StatusOfEachPersonEachMonth
left outer join A_GM_TBL_RegularGiving 
on A_GM_TBL_RegularGiving.constituentID = #StatusOfEachPersonEachMonth.ConstituentID
where GiverCategory = 'Active CoG only'
and CalendarYearMonth = 201506
;
select * from #RegularGiftDetails where ConstituentID = 1000094
;
select * from #RegularGivingResults where ConstituentID = 1000094
order by CalendarYearMonth
*/

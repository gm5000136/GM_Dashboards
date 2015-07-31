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
case when
--next line deals with 'null' and assumes they are all long in the past. Issue re-raised of getting these corrected on RE (and noted as issue on github)
s.[Gift Status Date] is null then 197912 else CalendarYearMonth end as MonthCancelled
from
A_GM_GiftStatusDate s 
inner join FACT_Gift g on g.GiftSystemID = s.[System Record ID]
left outer join DIM_Date d on d.ActualDate = s.[Gift Status Date]
where [Gift Status] in ('Terminated','Cancelled','Completed')
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


/* this approach failed
select
l.constituentID,
l.CalendarYearMonth,
case 
when 
r.ConstituentID is not null and c.ConstituentID  is not null 
and l.CalendarYearMonth = r.CalendarYearMonth
then 'ActiveCoG and ActiveCash'
when r.ConstituentID  is not null  
and l.CalendarYearMonth = r.CalendarYearMonth
then 'ActiveCoG only'
when c.ConstituentID  is not null
and l.CalendarYearMonth = c.CalendarYearMonth
then 'ActiveCash only'
end as Category
into #StatusOfEachPersonEachMonth
from
(
select constituentid,CalendarYearMonth from #RegularGiftDetails
union
select constituentid,CalendarYearMonth from #IndividualCashResults
) l
left outer join 
#RegularGiftDetails r 
on r.constituentID = l.constituentid
and r.CalendarYearMonth = l.CalendarYearMonth
left outer join 
#IndividualCashResults c on c.constituentID = l.constituentid
and c.CalendarYearMonth = l.CalendarYearMonth
*/

;

--40 Producing counts and sums of amounts for each month ever

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
--Could easily be limited by month to save time
--Individuals only
--Allows ANY regular giving payment, but cash are limited to the current 'DMT + MD' definition

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

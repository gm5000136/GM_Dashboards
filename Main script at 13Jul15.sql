--preprestep 1: appealidentifiers to be regarded as upgrade

select distinct AppealIdentifier 
into #AppealsToBeTreatedAsUpgrade
from DIM_Appeal a
inner join DIM_Campaign c on c.CampaignDimID = a.CampaignDimID
where 
(
AppealIdentifier like '%/u%'
and AppealIdentifier not like 'RA/%'
and AppealDescription not like '%Unallocated%'
and AppealDescription not like '%Unicef%'
)
or
c.CampaignDescription = 'Upgrade Activity'

--preprestep 2: appealidentifiers to be regarded as rollingSMS (for ID 58)
--relevant to cash payments only
select distinct left(packageidentifier,6) as RollingSMSAppealID 
into #AppealsToBeTreatedAsRollingSMS
from DIM_Package
where PackageCategoryDescription = 'SMS'
and (SUBSTRING(packageidentifier,4,3) = 'CAC' or SUBSTRING(packageidentifier,4,3) = 'CAD')


--prestep 1: store facts on all amendments

select 
GiftFactID_of_the_RG as UpgradedGift,
changeinannualisedamount as ChangeInAnnualisedValueFromUpgrade,
CalendarYearMonth as calendaryearmonth_of_amendment,
case 
when substring(VIEW_RG_History.AppealIdentifier,3,4) = '/UPR' then 'Welcome' 
when substring(VIEW_RG_History.AppealIdentifier,3,3) = '/UP' then 'Non-Welcome upgrade appeal' 
when VIEW_RG_History.AppealIdentifier IN (select * from #AppealsToBeTreatedAsUpgrade) then 'Non-Welcome upgrade appeal'
else 'Other'
End as AppealType,
VIEW_RG_History.AppealIdentifier, 
DIM_Package.PackageCategoryDescription,
DIM_Appeal.Product,
DIM_Audience.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments, --this is the RIGHT place to take audience from (same with team) - it is flattened correctly including overrides to FACT_Gift!!!
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor,
VIEW_RG_History.GiftCodeOfTheRG --Can be (and sometimes is...) null
into #AmendmentFacts
from VIEW_RG_History
inner join DIM_Date
on dim_date.DateDimID = VIEW_RG_History.[DatedimID of gift or amendment]
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier
inner join FACT_Gift on FACT_Gift.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join DIM_Audience on DIM_Audience.AudienceDimID = FACT_Gift.AudienceDimID
where 
ISoriginal = 0
and ChangeInAnnualisedAmount <> 0
--and [DatedimID of gift or amendment] > 20130331


--prestep 2: store facts on all cancellations
--so this is the COMPONENT VERSION

--?! work on something that attributes cancellations to the most recent appeal received ?! 
--see commented out script at end for interesting start

select 
VIEW_RG_History.GiftFactID_of_the_RG as CancelledGift,
-1*(VIEW_RG_History.ChangeInAnnualisedAmount) as ValueCancelled,
CalendarYearMonth,
case 
when substring(VIEW_RG_History.AppealIdentifier,3,4) = '/UPR' then 'Welcome' 
when substring(VIEW_RG_History.AppealIdentifier,3,3) = '/UP' then 'Non-Welcome upgrade appeal' 
when VIEW_RG_History.AppealIdentifier IN (select * from #AppealsToBeTreatedAsUpgrade) then 'Non-Welcome upgrade appeal'
else 'Other'
End as AppealTypeForUpgradesOnly,
VIEW_RG_History.AppealIdentifier, 
DIM_Package.PackageCategoryDescription,
DIM_Appeal.Product,
DIM_Audience.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments, --this is the RIGHT place to take audience from (same with team) - it is flattened correctly including overrides to FACT_Gift!!!
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor,
VIEW_RG_History.GiftCodeOfTheRG --Can be (and sometimes is...) null
into #CancellationFacts
from 
VIEW_RG_History
--left outer join A_GM_DashBoards_Grouping
--on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
inner join 
(select giftfactid,GiftSystemID from FACT_Gift where GiftTypeDimID in (8,30) and GiftStatusDimID in (3,5)) as AllCancelledRGsAllTypes on AllCancelledRGsAllTypes.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join A_GM_GiftStatusDate 
on A_GM_GiftStatusDate.[System Record ID] = AllCancelledRGsAllTypes.GiftSystemID
and A_GM_GiftStatusDate.[Gift Status] in ('Terminated','Canceled')
left outer join DIM_Date 
on [Gift Status Date] = ActualDate
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier
inner join FACT_Gift on FACT_Gift.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join DIM_Audience on DIM_Audience.AudienceDimID = FACT_Gift.AudienceDimID



--prestep 3: store facts on all new regular gifts

select 
VIEW_RG_History.GiftFactID_of_the_RG as Gift,
VIEW_RG_History.ChangeInAnnualisedAmount as AnnualValue,
CalendarYearMonth,
case 
when substring(VIEW_RG_History.AppealIdentifier,3,4) = '/UPR' then 'Welcome' 
when substring(VIEW_RG_History.AppealIdentifier,3,3) = '/UP' then 'Non-Welcome upgrade appeal' 
when VIEW_RG_History.AppealIdentifier IN (select * from #AppealsToBeTreatedAsUpgrade) then 'Non-Welcome upgrade appeal'
else 'Other'
End as AppealTypeForUpgradesOnly,
VIEW_RG_History.AppealIdentifier, 
DIM_Package.PackageCategoryDescription,
DIM_Appeal.Product,
DIM_Audience.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments, --this is the RIGHT place to take audience from (same with team) - it is flattened correctly including overrides to FACT_Gift!!!
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor,
VIEW_RG_History.GiftCodeOfTheRG --Can be (and sometimes is...) null
into #NewRGFacts
from 
VIEW_RG_History
--left outer join A_GM_DashBoards_Grouping
--on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
left outer join DIM_Date 
on VIEW_RG_History.[DatedimID of gift or amendment] = DIM_Date.DateDimID
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier
inner join FACT_Gift on FACT_Gift.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join DIM_Audience on DIM_Audience.AudienceDimID = FACT_Gift.AudienceDimID
where IsOriginal = 1




/*
--might behelpful for any checking
select view_rg_history.constituentID,#NewRGFacts.* from #NewRGFacts 
inner join view_rg_history on VIEW_RG_History.GiftFactID_of_the_RG = #NewRGFacts.gift
where AppealTypeForUpgradesOnly = 'Non-Welcome upgrade appeal'
and calendaryearmonth = 201504
*/



--prestep 4: store facts on all actual received RG payments
--this step for now has to trust the initial split done in morning job: 'Where the money comes from reporting - RG components' so cannot apply as many rules as in some other cases. Targets are simpler too though since people do not seem to set these at granular level.

--so we don't actually do any work - this is already stored each morning in: A_GM_REP_YTDSummary_RGPs
--it INCLUDES ALL REGULAR GIVING REGARDLESS OF PAYMENT TYPE!


--prestep 5
--initial work to summarise all events signups
--this includes adding them (in slightly more detail) to own table [A_GM_DashBoards_EventSignUpsFullerInfo]
--essentially, this is carrying out rules to define which event action relates to which ID, rules which are NOT
--written in the TowardsHierarchy spreadsheet
--this prestep is longish: it doesn't finish till we get to 'prestep 6'!

select sub.[Year of event],sub.[Signup month - based on when added to RE],sub.AttributeDescription as [Event Name],[RegistrationType],EventType,FundraisingPlatform,ActionType,[Date of event],COUNT(constituentID) as [SignupsInMonth]
into #EventSignUpFullList
		from  
		(  
		SELECT     TOP (100) PERCENT DIM_Constituent.ConstituentID, A_GM_ActionExtraInfo.[Action Date Added] AS [Signup date - based on when added to RE],   
		                      DIM_Date.CalendarYearMonth AS [Signup month - based on when added to RE], FACT_Action.ActionDateDimID AS [Date of event],   
		                      DIM_Date_1.CalendarYear AS [Year of event], FACT_ActionAttribute.AttributeDescription, DIM_ActionStatus.Description AS ActionStatus,   
		                      DIM_ActionType.Description AS ActionType, 
		                      case when RegistrationTypes.AttributeDescription is null then 'Neither' else RegistrationTypes.AttributeDescription end as RegistrationType,  
		                      case when eventtype.AttributeDescription is null then 'Other' else eventtype.AttributeDescription end as EventType,
		                      CASe when FundraisingPlatforms.AttributeDescription is null then '' else FundraisingPlatforms.AttributeDescription end as FundraisingPlatform
		FROM         FACT_Action INNER JOIN  
		                      FACT_ActionAttribute ON FACT_Action.ActionFactID = FACT_ActionAttribute.ActionFactID INNER JOIN  
		                      A_GM_ActionExtraInfo ON FACT_Action.ActionSystemID = A_GM_ActionExtraInfo.[Action System Record ID] INNER JOIN  
		                      DIM_ActionStatus ON FACT_Action.ActionStatusDimID = DIM_ActionStatus.ActionStatusDimID INNER JOIN  
		                      DIM_Constituent ON FACT_Action.ConstituentDimID = DIM_Constituent.ConstituentDimID INNER JOIN  
		                      DIM_ActionType ON FACT_Action.ActionTypeDimID = DIM_ActionType.ActionTypeDimID INNER JOIN  
		                      DIM_Date ON A_GM_ActionExtraInfo.[Action Date Added] = DIM_Date.ActualDate INNER JOIN  
		                      DIM_Date AS DIM_Date_1 ON FACT_Action.ActionDateDimID = DIM_Date_1.DateDimID  
		left outer join   
		( 
		SELECT     FACT_Action.ActionFactID, FACT_ActionAttribute.AttributeDescription  
		FROM         FACT_Action  
		INNER JOIN  
		FACT_ActionAttribute ON FACT_Action.ActionFactID = FACT_ActionAttribute.ActionFactID  
		WHERE    (FACT_ActionAttribute.AttributeCategory = 'Event Registration Type')  
		) as RegistrationTypes on FACT_Action.ActionFactID = RegistrationTypes.ActionFactID 
		left outer join   
		( 
		SELECT     FACT_Action.ActionFactID, FACT_ActionAttribute.AttributeDescription  
		FROM         FACT_Action  
		INNER JOIN  
		FACT_ActionAttribute ON FACT_Action.ActionFactID = FACT_ActionAttribute.ActionFactID  
		WHERE     (FACT_ActionAttribute.AttributeCategory = 'Event Category')  
		) as EventType on FACT_Action.ActionFactID = EventType.ActionFactID 
		left outer join
		(
		SELECT     FACT_Action.ActionFactID, FACT_ActionAttribute.AttributeCategory,FACT_ActionAttribute.AttributeDescription  
		FROM         FACT_Action  
		inner JOIN  
		FACT_ActionAttribute ON FACT_Action.ActionFactID = FACT_ActionAttribute.ActionFactID  
		WHERE     (FACT_ActionAttribute.AttributeCategory = 'Fundraising Platform Used')  
		) as FundraisingPlatforms on FundraisingPlatforms.ActionFactID = FACT_Action.ActionFactID
		WHERE      
		(FACT_ActionAttribute.AttributeCategory = 'Event Name') AND (DIM_ActionStatus.Description IN ('Participating', 'Accepted', 'Participated', 'Pending Approval',   
		                      'Day of event')) AND (DIM_ActionType.Description LIKE '%FR Event - %') AND (FACT_ActionAttribute.AttributeDescription IS NOT NULL) AND (DIM_Date.MonthsSince >-1)  
		) as sub
		group by [Year of event],[Signup month - based on when added to RE], AttributeDescription,[RegistrationType],[EventType],FundraisingPlatform,ActionType,[Date of event]
		order by [Year of event],[Event Name],[Signup month - based on when added to RE] asc 
;

--EventSignUps are created here, populated to A_GM_DashBoards_EventSignUpsFullerInfo
--Short table so just dropping and replacing rather than anything more standard
--THEN usual facts are taken from that table into the select
drop table A_GM_DashBoards_EventSignUpsFullerInfo
;
SELECT 
Type,
d.CalendarYearMonth,
subtosum.ID,
subtosum.FormsPartOf,
subtosum.Level,
A_GM_DashBoards_Grouping.Description,
[Event Name],
CalendarYearMonthThatEventTookPlace,
SUM([Count]) as [Count],
d.CalendarYear,
d.FiscalYear,
d.CalendarMonthName,
d.MonthsSince
into A_GM_DashBoards_EventSignUpsFullerInfo
FROM
(
select
'SignUpsDuringMonth' as Type,
[Signup month - based on when added to RE] as CalendarYearMonth,
case
when
EventType = 'Peer to peer event'
AND
ActionType 
in
(
'FR Event - Adrenaline',
'FR Event - Climbing',
'FR Event - Cycling',
'FR Event - Half Marathon',
'FR Event - Marathon',
'FR Event - Multi-discipline Event',
'FR Event - Obstacle',
'FR Event - Other Running',
'FR Event - Walking',
'FR Event - Water Related'
) then 84 --p2p challenge
when
EventType = 'Peer to peer event'
AND ActionType 
in
(
'FR Event - Music/Dancing',
'FR Event - Dinner', -- has never been one that is also p2p!
'FR Event - Food and Drink'
) then 85 --p2p social fundraising
when
EventType = 'Peer to peer event'
AND ActionType 
in
(
'FR Event - Celebration'
) then 86 --p2p celebration
when
EventType = 'Peer to peer event'
then 87
when EventType = 'WaterAid Mass Participation Event' then 88 --all with this event type regardless of anything else
when 
ActionType 
in
(
'FR Event - Adrenaline',
'FR Event - Climbing',
'FR Event - Cycling',
'FR Event - Half Marathon',
'FR Event - Marathon',
'FR Event - Multi-discipline Event',
'FR Event - Obstacle',
'FR Event - Other Running',
'FR Event - Walking',
'FR Event - Water Related'
) then 25 --any remaining active-sounding event!
else 27 --everything remaining, ones we'd actually had as at 7Aug15 were as below 
--(some of these will have been separated out above IF they are peer-to-peer event)
--FR Event - Appeal Fundraising
--FR Event - Celebration
--FR Event - Food and Drink
--FR Event - In Memory
--FR Event - Just Water
--FR Event - Miscellaneous Event
--FR Event - Music/Dancing
--FR Event - Online Page Unknown
end as ID, 
case 
when EventType = 'Peer to peer event' then 24 --P2P
else 13 --everything that is not peer-to-peer
end as FormsPartOf, 
8 as Level,
--Description is taken from the join with dashboard list
#EventSignUpFullList.[Event Name],
left(#EventSignUpFullList.[Date of event],6) as CalendarYearMonthThatEventTookPlace,
[SignupsInMonth] as [Count]
from
#EventSignUpFullList
) subtosum
left outer join A_GM_DashBoards_Grouping
on subtosum.ID = A_GM_DashBoards_Grouping.id
inner join --finding myself having to do this a lot to avoid multiplying by every day in each month!
(select distinct 
CalendarYearMonth,
CalendarYear,
FiscalYear,
CalendarMonthName,
MonthsSince
from DIM_Date) d on d.CalendarYearMonth = subtosum.CalendarYearMonth
group by 
Type,
d.CalendarYearMonth,
subtosum.ID,
subtosum.FormsPartOf,
subtosum.Level,
A_GM_DashBoards_Grouping.Description,
[Event Name],
CalendarYearMonthThatEventTookPlace,
d.CalendarYear,
d.FiscalYear,
d.CalendarMonthName,
d.MonthsSince
;
--insert into that table a row with count 0 for every month since an action happened
--except those that are actually in the real table
--this makes YTD and other counts adds up
--in future we'd do dimensionally somehow (this is 'recording what didn't happen')
insert into A_GM_DashBoards_EventSignUpsFullerInfo
select distinct
[Type],
d.[CalendarYearMonth],
[ID],
[FormsPartOf],
[Level],
[Description],
[Event Name],
CalendarYearMonthThatEventTookPlace,
[Count],
d.[CalendarYear],
d.[FiscalYear],
d.[CalendarMonthName],
d.[MonthsSince]
from

(
SELECT distinct
       t1.[Type]
      ,d.[CalendarYearMonth]
      ,t1.[ID]
      ,t1.[FormsPartOf]
      ,t1.[Level]
      ,t1.[Description]
      ,t1.[Event Name]
      ,CalendarYearMonthThatEventTookPlace
      ,0 as [Count]
      /* get these from date
      ,t1.[CalendarYear]
      ,t1.[FiscalYear]
      ,t1.[CalendarMonthName]
      ,t1.[MonthsSince]
      */
  FROM A_GM_DashBoards_EventSignUpsFullerInfo t1
 right outer join 
 (
 select distinct calendaryearmonth from DIM_Date
 where MonthsSince > -1
 ) d on d.CalendarYearMonth >= t1.CalendarYearMonth
except select 
       [Type]
      ,[CalendarYearMonth]
      ,[ID]
      ,[FormsPartOf]
      ,[Level]
      ,[Description]
      ,[Event Name]
      ,CalendarYearMonthThatEventTookPlace
      ,0 as [DummyCount]
from A_GM_DashBoards_EventSignUpsFullerInfo
) FindingEveryZeroRow
inner join DIM_Date d on d.CalendarYearMonth = FindingEveryZeroRow.CalendarYearMonth
where type is not null
/* for checking
and
[Event Name] = 'London Marathon'
and CalendarYearMonth > 201412
*/
;
--prestep 6 - populate table of full details of all pack requests and use that to summarise these in main work
--this is longish - it finishes at 'step 1'

select sub.[FYYearEndingOfSend],sub.[Pack send month] as PackSendMonth,ActionType,ConstituentType,COUNT(constituentID) as [SendsInMonth] 
into #PackRequestFullList
from 
( 
SELECT distinct --so if the same constituent orders two packs they are counted once only
DIM_Constituent.ConstituentID, 
DIM_Date.CalendarYearMonth AS [Pack send month], 
FACT_Action.ActionDateDimID AS [Date of pack send], 
DIM_Date.FiscalYear AS [FYYearEndingOfSend], 
DIM_ActionStatus.Description AS ActionStatus, 
DIM_ActionType.Description AS ActionType,
ConstituentTypes.ConstituentType
FROM         FACT_Action INNER JOIN
DIM_ActionStatus ON FACT_Action.ActionStatusDimID = DIM_ActionStatus.ActionStatusDimID INNER JOIN
DIM_Constituent ON FACT_Action.ConstituentDimID = DIM_Constituent.ConstituentDimID INNER JOIN
DIM_ActionType ON FACT_Action.ActionTypeDimID = DIM_ActionType.ActionTypeDimID INNER JOIN
DIM_Date ON FACT_Action.ActionDate = DIM_Date.ActualDate
inner join 
(
SELECT  distinct   DIM_Constituent.ConstituentID, 
CASE 
WHEN ConstituentCode = 'Schools' THEN 'School' 
WHEN ConstituentCode = 'Faith Groups' THEN 'Faith Group' 
ELSE 'Neither' END AS ConstituentType
FROM         
DIM_Constituent LEFT OUTER JOIN
DIM_ConstituentConstitCode ON DIM_Constituent.ConstituentDimID = DIM_ConstituentConstitCode.ConstituentDimID
) as ConstituentTypes on DIM_Constituent.ConstituentID = ConstituentTypes.ConstituentID
WHERE     (DIM_ActionStatus.Description = 'Sent') AND (DIM_ActionType.Description LIKE '%FR Pack - %') AND 
(DIM_Date.MonthsSince >-1)
) as sub 
group by [FYYearEndingOfSend],ActionType,ConstituentType,[Pack send month]
order by [FYYearEndingOfSend],[Pack send month] asc
;
--PackRequests are created here, populated to A_GM_DashBoards_PackRequestsFullerInfo
--Short table so just dropping and replacing rather than anything more standard
--THEN usual facts are taken from that table into the select
drop table A_GM_DashBoards_PackRequestsFullerInfo
;
SELECT 
Type,
d.CalendarYearMonth,
subtosum.ID,
subtosum.FormsPartOf,
subtosum.Level,
A_GM_DashBoards_Grouping.Description,
ActionType,
SUM([SendsInMonth]) as [SendsInMonth],
d.CalendarYear,
d.FiscalYear,
d.CalendarMonthName,
d.MonthsSince
into A_GM_DashBoards_PackRequestsFullerInfo
FROM
(
select
'ReceivedPackDuringMonth' as Type,
PackSendMonth as CalendarYearMonth,
case
when
ConstituentType = 'School'
then 29 --distinct schools receiving pack
when
ConstituentType = 'Faith Group'
then 28 --distinct faith groups receiving pack
else 31 --all other distinct people receiving pack THEY MAY NOT ALL BE COMMUNITY?
end AS ID,
14 as FormsPartOf, 
8 as Level,
--Description is taken from the join with dashboard list
#PackRequestFullList.ActionType,
[SendsInMonth]
from
#PackRequestFullList
) subtosum
left outer join A_GM_DashBoards_Grouping
on subtosum.ID = A_GM_DashBoards_Grouping.id
inner join --finding myself having to do this a lot to avoid multiplying by every day in each month!
(select distinct 
CalendarYearMonth,
CalendarYear,
FiscalYear,
CalendarMonthName,
MonthsSince
from DIM_Date) d on d.CalendarYearMonth = subtosum.CalendarYearMonth
group by 
Type,
d.CalendarYearMonth,
subtosum.ID,
subtosum.FormsPartOf,
subtosum.Level,
A_GM_DashBoards_Grouping.Description,
ActionType,
d.CalendarYear,
d.FiscalYear,
d.CalendarMonthName,
d.MonthsSince
;

--insert into that table a row with count 0 for every month since an action happened
--except those that are actually in the real table
--this makes YTD and other counts adds up
--in future we'd do dimensionally somehow (this is 'recording what didn't happen')
insert into A_GM_DashBoards_PackRequestsFullerInfo
select distinct
[Type],
d.[CalendarYearMonth],
[ID],
[FormsPartOf],
[Level],
[Description],
ActionType,
[Count],
d.[CalendarYear],
d.[FiscalYear],
d.[CalendarMonthName],
d.[MonthsSince]
from

(
SELECT distinct
       t1.[Type]
      ,d.[CalendarYearMonth]
      ,t1.[ID]
      ,t1.[FormsPartOf]
      ,t1.[Level]
      ,t1.[Description]
      ,t1.ActionType
      ,0 as [Count]
      /* get these from date
      ,t1.[CalendarYear]
      ,t1.[FiscalYear]
      ,t1.[CalendarMonthName]
      ,t1.[MonthsSince]
      */
  FROM A_GM_DashBoards_PackRequestsFullerInfo t1
 right outer join 
 (
 select distinct calendaryearmonth from DIM_Date
 where MonthsSince > -1
 ) d on d.CalendarYearMonth >= t1.CalendarYearMonth
except select 
       [Type]
      ,[CalendarYearMonth]
      ,[ID]
      ,[FormsPartOf]
      ,[Level]
      ,[Description]
      ,ActionType
      ,0 as [DummyCount]
from A_GM_DashBoards_PackRequestsFullerInfo
) FindingEveryZeroRow
inner join DIM_Date d on d.CalendarYearMonth = FindingEveryZeroRow.CalendarYearMonth
where type is not null
;



--step 1: new annualised value of regular gifts for each ID and each month

SELECT 
subtogetvalues.Type,
SubToGetValues.CalendarYearMonth,
SubToGetValues.ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]

into #MainResultsTable

from
(
select
'AnnualValueOfNewRegularGifts' as [Type],
CalendarYearMonth,
case 
--HV re-jigged per Ado 12Feb16 - ignores team-campaign and rules now! Risk of some falling to 999?
WHEN 
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
and Product = 'Donor Reporting'
then 72
--when TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' then 71 --NOT THIS LINE - FOR CASH ONLY!
/*OLD WAY OF DEALING WITH HV HERE
--This first one moves ANY Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV AND the product is 'direct solicited donations' to 'HV Direct Solicited'. 
--This is because that means the person was account managed by HV, so anything they do is credited to that team!
--This is often LOST for amendments as target audience changes are not put on the amendment
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' 
and Product = 'Direct Solicited Donations'
and RuleNumberToApply not IN ('17','18','19','23','24') then 73
*/
--new rules added 12Feb16 for IDs 52,63, 35 and 62, per Ado's description of how to find
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or mainsummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = 'Regular Gifts - Doordrop' 
then 52
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Hothouse','Regular Gifts - BRTV','Regular Gifts - Hothouse BRTV','Regular Gifts - Hothouse Door Drop')
then 63
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Inserts')
then 35
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = ('Regular Gifts - Word of Mouth')
then 62
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
--A couple of steps to cover RULE 4:
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
	when RuleNumberToApply = 4 and Product = 'PPC' then 45
	when RuleNumberToApply = 4 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 4 then 39
	when RuleNumberToApply = 21 and Product = 'PPC' then 45
	when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 21 then 39
WHEN RuleNumberToApply = 5 Then 51 --No such thing as regular wahoo, so any would have to be shop
WHEN RuleNumberToApply = 6 and Product = 'PPC' then 45
when RuleNumberToApply = 6 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 6 THEN 54
--WHEN RuleNumberToApply = 7 and GiftCodeOfTheRG = 'SMS' then 55 --old version, has it been completely superseeded correctly by below?
WHEN RuleNumberToApply = 7 and Product = 'PSMS - DRTV' then 55
WHEN RuleNumberToApply = 7 then 33
/*OLD WAY OF DEALING WITH HV HERE
when
	RuleNumberToApply in (17,18,19) 
	AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN RuleNumberToApply in (17,18,19) then 72
*/
--Rule21 dealt with 4 above
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Telephone') 
then 79
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 78
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Telephone') 
then 37
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 64
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Telephone') 
then 65
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 66
When RuleNumberToApply = 23 then 50
--updated rule 20 in case it had been including PPC and/or facebook
WHEN RuleNumberToApply = 20 and Product = 'PPC' then 45
when RuleNumberToApply = 20 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 20 then 50
--rule 21 dealt along with rule 4 earlier on
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
--WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72 --OLD WAY
when RuleNumberToApply = 24 then 49
WHEN RuleNumberToApply = 26 THEN 53 --Will be more complex than this in reality
else 999
end as ID,
[Total]
from
(
	select
	n.CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	n.AppealTypeForUpgradesOnly as AppealTypeFromAppealID,
	PackageCategoryDescription,
	GiftCodeOfTheRG,
	SUM(n.AnnualValue) as [Total]
	from 
	#NewRGFacts N
	--where n.CalendarYearMonth > 201503
	group by 
	CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealTypeForUpgradesOnly,
	PackageCategoryDescription,
	GiftCodeOfTheRG
	--order by GM_TIEStyle_CampaignDescriptor
) AS MainSummary
left outer join A_GM_Dashboards_KnownDescriptors
on A_GM_Dashboards_KnownDescriptors.GM_TIEStyle_CampaignDescriptor = MainSummary.GM_TIEStyle_CampaignDescriptor
) SubToGetValues
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = subtogetvalues.ID
group by 
Type,
CalendarYearMonth,
subtogetvalues.ID,
FormsPartOf,
Level,
Description

union all

/* old step 1
select
'AnnualValueOfNewRegularGifts' as [Type],
CalendarYearMonth, 
ID,
FormsPartOf,
Level,
Description,
SUM(VIEW_RG_History.ChangeInAnnualisedAmount) as [Total]
from VIEW_RG_History 
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
inner join DIM_Date on dim_date.DateDimID = VIEW_RG_History.[DatedimID of gift or amendment]
where VIEW_RG_History.IsOriginal = 1
--and VIEW_RG_History.[DatedimID of gift or amendment] >201503
group by CalendarYearMonth,ID,FormsPartOf,Level,Description
*/


--step 2: annualised value of new changes to regular gifts for each ID and each month, will incorporate downgrades as well as upgrades
--This one has now (29May15) been adapted to use rules, as cash does
--Intention is for the central sub of this to be a useful summary, although it doesn't go all the way to gift level (easily can though)



SELECT 
subtogetvalues.Type,
SubToGetValues.CalendarYearMonth,
SubToGetValues.ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]
from
(
select
'AnnualValueOfChangesToRegularGifts' as [Type],
calendaryearmonth_of_amendment as CalendarYearMonth,
case 
--HV re-jigged per Ado 12Feb16 - ignores team-campaign and rules now! Risk of some falling to 999?
WHEN 
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
and Product = 'Donor Reporting'
then 72
--when TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' Then 71 --NOT HERE: CASH
/* OLD HV HERE
--This first one moves ANY Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV AND the product is 'direct solicited donations' to 'HV Direct Solicited'. 
--This is because that means the person was account managed by HV, so anything they do is credited to that team!
--This is often LOST for amendments as target audience changes are not put on the amendment
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' 
and Product = 'Direct Solicited Donations'
and RuleNumberToApply not IN ('17','18','19','23','24') then 73
*/
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
--new rules added 12Feb16 for IDs 52,63, 35 and 62, per Ado's description of how to find
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or mainsummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = 'Regular Gifts - Doordrop' 
then 52
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Hothouse','Regular Gifts - BRTV','Regular Gifts - Hothouse BRTV','Regular Gifts - Hothouse Door Drop')
then 63
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Inserts')
then 35
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = ('Regular Gifts - Word of Mouth')
then 62
--A couple of steps to cover RULE 4:
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
	when RuleNumberToApply = 4 and Product = 'PPC' then 45
	when RuleNumberToApply = 4 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 4 then 39
	when RuleNumberToApply = 21 and Product = 'PPC' then 45
	when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 21 then 39
WHEN RuleNumberToApply = 5 Then 51 --No such thing as regular wahoo, so any would have to be shop
WHEN RuleNumberToApply = 6 and Product = 'PPC' then 45
when RuleNumberToApply = 6 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 6 THEN 54
--WHEN RuleNumberToApply = 7 and GiftCodeOfTheRG = 'SMS' then 55 --old version, has it been completely superseeded correctly by below?
WHEN RuleNumberToApply = 7 and Product = 'PSMS - DRTV' then 55
WHEN RuleNumberToApply = 7 then 33
/* old hv
when
	RuleNumberToApply in (17,18,19) 
	AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN RuleNumberToApply in (17,18,19) then 72
*/
--Rule21 dealt with 4 above
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Telephone') 
then 79
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 78
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Telephone') 
then 37
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 64
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Telephone') 
then 65
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 66
When RuleNumberToApply = 23 then 50
--updated rule 20 in case it had been including PPC and/or facebook
WHEN RuleNumberToApply = 20 and Product = 'PPC' then 45
when RuleNumberToApply = 20 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 20 then 50
--rule 21 dealt along with rule 4 earlier on
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
--WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72 --old hv
when RuleNumberToApply = 24 then 49
WHEN RuleNumberToApply = 26 THEN 53 --Will be more complex than this in reality
else 999
end as ID,
[Total]
from
(
	select
	calendaryearmonth_of_amendment,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealType as AppealTypeFromAppealID,
	PackageCategoryDescription,
	GiftCodeOfTheRG,
	SUM(ChangeInAnnualisedValueFromUpgrade) as [Total]
	from 
	#AmendmentFacts
	--where calendaryearmonth_of_amendment > 201503
	group by 
	calendaryearmonth_of_amendment,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealType,
	PackageCategoryDescription,
	GiftCodeOfTheRG
	--order by GM_TIEStyle_CampaignDescriptor
) AS MainSummary
inner join A_GM_Dashboards_KnownDescriptors
on A_GM_Dashboards_KnownDescriptors.GM_TIEStyle_CampaignDescriptor = MainSummary.GM_TIEStyle_CampaignDescriptor
) SubToGetValues
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = subtogetvalues.ID
group by 
Type,
CalendarYearMonth,
subtogetvalues.ID,
FormsPartOf,
Level,
Description








--note: neither of the above take any account of cancellations

union all

--so step 3 - something I've not seen here before - also figure out the annualised value of the cancellations each month by the current component split of that gift at the point of cancellation...
--is this a good way to do; would we be better treating the cancellation appeal as having caused the whole loss of income for that gift (interesting for upgrade!)...
--can help us look into 'running fast to stand still' example: extent to which new upgrade components outstrip the 

--values are negative, so that adding numbers 1 and 2 to this will gives us 'net change in value' for that month

SELECT 
subtogetvalues.Type,
SubToGetValues.CalendarYearMonth,
SubToGetValues.ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]
from
(
select
'AnnualValueCancelledThisMonth' as [Type],
CalendarYearMonth,
case 
--HV re-jigged per Ado 12Feb16 - ignores team-campaign and rules now! Risk of some falling to 999?
WHEN 
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
and Product = 'Donor Reporting'
then 72
--when TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' then 71 --NOT HERE - ONLY APPLIES TO CASH
/* OLD HV
--This first one moves ANY Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV AND the product is 'direct solicited donations' to 'HV Direct Solicited'. 
--This is because that means the person was account managed by HV, so anything they do is credited to that team!
--This is often LOST for amendments as target audience changes are not put on the amendment
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' 
and Product = 'Direct Solicited Donations'
and RuleNumberToApply not IN ('17','18','19','23','24') then 73
*/
--new rules added 12Feb16 for IDs 52,63, 35 and 62, per Ado's description of how to find
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or mainsummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = 'Regular Gifts - Doordrop' 
then 52
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Hothouse','Regular Gifts - BRTV','Regular Gifts - Hothouse BRTV','Regular Gifts - Hothouse Door Drop')
then 63
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Inserts')
then 35
when 
(MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or MainSummary.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = ('Regular Gifts - Word of Mouth')
then 62
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
--A couple of steps to cover RULE 4:
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
	when RuleNumberToApply = 4 and Product = 'PPC' then 45
	when RuleNumberToApply = 4 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 4 then 39
	when RuleNumberToApply = 21 and Product = 'PPC' then 45
	when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 21 then 39
WHEN RuleNumberToApply = 5 Then 51 --No such thing as regular wahoo, so any would have to be shop
WHEN RuleNumberToApply = 6 and Product = 'PPC' then 45
when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 6 THEN 54
--WHEN RuleNumberToApply = 7 and GiftCodeOfTheRG = 'SMS' then 55 --old version, has it been completely superseeded correctly by below?
WHEN RuleNumberToApply = 7 and Product = 'PSMS - DRTV' then 55
WHEN RuleNumberToApply = 7 then 33
/* OLD HV
when
	RuleNumberToApply in (17,18,19) 
	AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN RuleNumberToApply in (17,18,19) then 72
*/
--Rule21 dealt with 4 above
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Telephone') 
then 79
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 78
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Telephone') 
then 37
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 64
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Telephone') 
then 65
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 66
When RuleNumberToApply = 23 then 50
--updated rule 20 in case it had been including PPC and/or facebook
WHEN RuleNumberToApply = 20 and Product = 'PPC' then 45
when RuleNumberToApply = 20 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 20 then 50
--rule 21 dealt along with rule 4 earlier on
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
--WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72 --OLD HV
when RuleNumberToApply = 24 then 49
WHEN RuleNumberToApply = 26 THEN 53 --Will be more complex than this in reality
else 999
end as ID,
[Total]
from
(
	select
	c.CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	c.AppealTypeForUpgradesOnly as AppealTypeFromAppealID,
	PackageCategoryDescription,
	GiftCodeOfTheRG,
	SUM(c.ValueCancelled) as [Total]
	from 
	#CancellationFacts C
	--where c.CalendarYearMonth > 201503
	group by 
	CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealTypeForUpgradesOnly,
	PackageCategoryDescription,
	GiftCodeOfTheRG
	--order by GM_TIEStyle_CampaignDescriptor
) AS MainSummary
inner join A_GM_Dashboards_KnownDescriptors
on A_GM_Dashboards_KnownDescriptors.GM_TIEStyle_CampaignDescriptor = MainSummary.GM_TIEStyle_CampaignDescriptor
) SubToGetValues
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = subtogetvalues.ID
group by 
Type,
CalendarYearMonth,
subtogetvalues.ID,
FormsPartOf,
Level,
Description

























/*old step 3
select 
'AnnualValueCancelledThisMonth' as [Type],
CalendarYearMonth, 
ID,
FormsPartOf,
Level,
Description,
-1*(SUM(VIEW_RG_History.ChangeInAnnualisedAmount)) as [Total]
from 
VIEW_RG_History
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
inner join 
(select giftfactid,GiftSystemID from FACT_Gift where GiftTypeDimID in (8,30) and GiftStatusDimID in (3,5)) as AllCancelledRGsAllTypes on AllCancelledRGsAllTypes.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join A_GM_GiftStatusDate 
on A_GM_GiftStatusDate.[System Record ID] = AllCancelledRGsAllTypes.GiftSystemID
and A_GM_GiftStatusDate.[Gift Status] in ('Terminated','Cancelled')
left outer join DIM_Date 
on [Gift Status Date] = ActualDateString
group by CalendarYearMonth,ID,FormsPartOf,Level,Description
*/

union all

--step 4: actual cash received by component

select
'ValueOfCashGifts' as [Type],
CalendarYearMonth, 
ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]
from
(
select
CASE 
--HV re-jigged per Ado 12Feb16 - ignores team-campaign and rules now! Risk of some falling to 999?
WHEN 
	TargetAudience  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN 
TargetAudience  = 'High Value Supporter' 
and Product = 'Donor Reporting'
then 72
when
TargetAudience  = 'High Value Supporter' --this applies here since this is cash!
then 71
/* OLD HV HERE
--This first one moves ANY Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV AND the product is 'direct solicited donations' to 'HV Direct Solicited'. 
--This is because that means the person was account managed by HV, so anything they do is credited to that team!
--This is often LOST for amendments as target audience changes are not put on the amendment
WHEN 
TargetAudience = 'High Value Supporter' 
and Product = 'Direct Solicited Donations'
and RuleNumberToApply not IN ('17','18','19','23','24') then 73
*/
--this second one for cash only applies the 'pre-rule' for rollingSMS, not currently a numbered rule (since campaign is not of use to us)
WHEN sub.appealidentifier in (select RollingSMSAppealID from #AppealsToBeTreatedAsRollingSMS) then 58
--rule C1: separate out all peer to peer WHERE A COMMUNITY OR EVENTS GIFT
when (sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%')
and sub.TargetAudience = 'Peer to Peer Fundraiser'
and 
(
sub.GM_TIEStyle_CampaignDescriptor like '%Running%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Walking%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Climbing%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Cycling%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Other Sports%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Obstacle%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Water Related%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Triathlon%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Multi-Discipline%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Marathon%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Adrenaline%'
)
then 84
when (sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%')
and sub.TargetAudience = 'Peer to Peer Fundraiser'
and 
(
sub.GM_TIEStyle_CampaignDescriptor like '%In Celebration%'
)
then 86
when (sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%')
and sub.TargetAudience = 'Peer to Peer Fundraiser'
then 87
--that's the end of rule 1. At the moment, not enough detail to add any gifts to number 85
--rule CE2: assign Glastonbury gifts received in any part of community or events
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
sub.Product = 'Glastonbury Festival'
then 26
--rule CE3. For the remaining (i.e. not peer-to-peer and not glastonbury) events and community gifts...lots in the one rule to keep numbering
--rule CE3 part 1: mass participation
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
Product in ('WaterAid 200','Tough Sh!t') --these were the only ones time of writing 28Jul15
then 88
--rule CE3 part 2: running/cycling/other active events
when (sub.GM_TIEStyle_CampaignDescriptor like 'Event%' OR sub.GM_TIEStyle_CampaignDescriptor like 'Comm%')
and 
(
sub.GM_TIEStyle_CampaignDescriptor like '%Running%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Walking%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Climbing%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Cycling%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Other Sports%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Obstacle%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Water Related%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Triathlon%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Multi-Discipline%'
OR
sub.GM_TIEStyle_CampaignDescriptor like '%Marathon%'
or
sub.GM_TIEStyle_CampaignDescriptor like '%Adrenaline%'
)
then 25
--rule CE3 part 3: other events fundraising (i.e. all else starting events)
when (sub.GM_TIEStyle_CampaignDescriptor like 'Event%') then 27
--rule CE3 part 4: split community based on target audience
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Faith Groups' then 28
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Schools' then 29
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Local Groups' then 89
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Choir Groups' then 91
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Youth Groups' then 92
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience = 'Universities' then 93
when 
--(sub.GM_TIEStyle_CampaignDescriptor like 'Comm%') and 
TargetAudience 
IN
(
'Inner Wheel Clubs',
'Lions',
'Other Community Groups', --I put these here for now, not 100% sure they should be?
'Other Professional Groups',
'Other Women''s Groups',
'Rotary',
'Soroptimist Clubs'
)
then 30
--new rules added 12Feb16 for IDs 52,63, 35 and 62, per Ado's description of how to find
when 
(sub.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or sub.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = 'Regular Gifts - Doordrop' 
then 52
when 
(sub.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or sub.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Hothouse','Regular Gifts - BRTV','Regular Gifts - Hothouse BRTV','Regular Gifts - Hothouse Door Drop')
then 63
when 
(sub.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or sub.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Inserts')
then 35
when 
(sub.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or sub.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = ('Regular Gifts - Word of Mouth')
then 62
--no speaker network gifts at the moment - Caroline told me they'd be better kept with the target audience of the gifts, although informal(ish) attempts to measure effect of talks on giving are made
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID --we are now passed the 'pre-rule' stuff...
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudience = 'Small Trusts'
	then 75
	when RuleNumberToApply = 4 and Product = 'PPC' then 45
	when RuleNumberToApply = 4 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 4 then 39
	when RuleNumberToApply = 21 and Product = 'PPC' then 45
	when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 21 then 39
WHEN RuleNumberToApply = 5 and (GiftCode like '%Wahoo%' or Product = 'Wahoo Gifting') THEN 46	
WHEN RuleNumberToApply = 5 Then 51 --No such thing as regular wahoo, so any would have to be shop
WHEN RuleNumberToApply = 6 and Product = 'PPC' then 45
when RuleNumberToApply = 6 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 6 THEN 53
--WHEN RuleNumberToApply = 7 and GiftCodeOfTheRG = 'SMS' then 55 --old version, has it been completely superseeded correctly by below?
WHEN RuleNumberToApply = 7 and Product = 'PSMS - DRTV' then 55
WHEN RuleNumberToApply = 7 then 33

--updated rule 20 in case it had been including PPC and/or facebook
WHEN RuleNumberToApply = 20 and Product = 'PPC' then 45
when RuleNumberToApply = 20 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 20 then 50
--rule 21 dealt along with rule 4 earlier on
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
when RuleNumberToApply = 24 then 49 --HV part that used to be here now dealt with earlier
WHEN RuleNumberToApply = 26 THEN 53 --Will be more complex than this in reality
ELSE 999 END AS DashGroup,
DIM_Date.CalendarYearMonth,
sub.GM_TIEStyle_CampaignDescriptor,
Amount as [Total]
from

(
SELECT     sub.ConstituentID, sub.GiftFactID_of_the_CashGift, sub.AppealDescription, sub.AppealIdentifier, sub.CampaignIdentifier, 
                      sub.CampaignDescription, sub.PackageIdentifier, sub.PackageDescription, sub.[DatedimID of gift], sub.Amount,GCs.Description AS GiftCode,allproducts.Product,alltargetaudiences.Targetaudience,   
                      CASE WHEN teams.team = 'CF/IS' THEN 'SDev - Appeal Unknown' WHEN teams.team = 'CF/IS/AU' THEN 'SDev - Autumn Cash Appeal' WHEN
                       teams.team = 'CF/IS/CA' THEN 'SDev - Feedback Activity' WHEN teams.team = 'CF/IS/CC' THEN 'SRec - Water Company Customer Campaign'
                       WHEN teams.team = 'CF/IS/CV' THEN 'SDev - Conversion to Committed Giving' WHEN teams.team = 'CF/IS/DM' THEN 'SRec - Cold Direct Mail'
                       WHEN teams.team = 'CF/IS/DR' THEN 'SDev - Doordrop Activity' WHEN teams.team = 'CF/IS/EA' THEN 'SDev - Other Cash Appeals' WHEN
                       teams.team = 'CF/IS/GA' THEN 'SDev - Gift Aid Activity' WHEN teams.team = 'CF/IS/HV' THEN 'SDev - High Value Supporter Activity - Cash & RG Ask'
                       WHEN teams.team = 'CF/IS/IN' THEN 'SRec - Inserts' WHEN teams.team = 'CF/IS/OA' THEN 'SDev - Supporter Magazine Oasis' WHEN teams.team
                       = 'CF/IS/PH' THEN 'SRec - Cold Telephone' WHEN teams.team = 'CF/IS/PR' THEN 'SRec - Press Advertisements' WHEN teams.team = 'CF/IS/RV'
                       THEN 'SDev - Reactivation Activity' WHEN teams.team = 'CF/IS/SH' THEN 'SDev - Shop Online & Offline' WHEN teams.team = 'CF/IS/SP'
                       THEN 'SDev - Spring Cash Appeal' WHEN teams.team = 'CF/IS/SU' THEN 'SDev - Summer Cash Appeal' WHEN teams.team = 'CF/IS/TV' THEN
                       'SRec - Direct Response TV Ad' WHEN teams.team = 'CF/IS/UP' THEN 'SDev - Upgrade Activity' WHEN teams.team = 'CF/IS/WB' THEN 'SRec - Online Not Categorised'
                       WHEN teams.team = 'CF/IS/WI' THEN 'SDev - Winter Cash Appeal' WHEN teams.team = 'CF/MD' THEN 'MajD - Not Categorised' WHEN teams.team
                       = 'NF' THEN 'NatF - Not Categorised' WHEN teams.team = 'NF/CM' THEN 'Comm - Not Categorised' WHEN teams.team = 'NF/CR' THEN 'Corp - Not Categorised'
                       WHEN teams.team = 'NF/PG' THEN 'Corp - Payroll Giving Appeals' WHEN teams.team = 'NF/RE' THEN 'WIP - Not Categorised' WHEN teams.team
                       = 'PP' THEN 'SDev - Campaigning Activity' ELSE (teams.team + ' - ' + DIM_Appeal_1.[CampaignDescription]) 
                      END AS GM_TIEStyle_CampaignDescriptor                             
FROM         

(
SELECT     dbo.DIM_Constituent.ConstituentID, dbo.FACT_Gift.GiftFactID AS GiftFactID_of_the_CashGift, dbo.DIM_Appeal.AppealDescription, dbo.DIM_Appeal.AppealIdentifier, dbo.DIM_Campaign.CampaignIdentifier, 
                                              dbo.DIM_Campaign.CampaignDescription, dbo.DIM_Package.PackageIdentifier, dbo.DIM_Package.PackageDescription, 
                                              dbo.FACT_Gift.GiftDateDimID AS [DatedimID of gift], dbo.FACT_Gift.Amount
                       FROM                dbo.FACT_Gift  INNER JOIN
                                              dbo.DIM_Constituent ON dbo.FACT_Gift.ConstituentDimID = dbo.DIM_Constituent.ConstituentDimID LEFT OUTER JOIN
                                              dbo.DIM_Package ON dbo.FACT_Gift.PackageDimID = dbo.DIM_Package.PackageDimID LEFT OUTER JOIN
                                              dbo.DIM_Appeal ON dbo.FACT_Gift.AppealDimID = dbo.DIM_Appeal.AppealDimID LEFT OUTER JOIN
                                              dbo.DIM_Campaign ON dbo.FACT_Gift.CampaignDimID = dbo.DIM_Campaign.CampaignDimID
WHERE      (dbo.FACT_Gift.GiftTypeDimID IN (1))
) AS sub 
INNER JOIN
(
select giftfactID,dim_team.Team
from FACT_Gift
inner join DIM_Team on dim_team.TeamDimID = fact_gift.TeamDimID
where fact_gift.GiftTypeDimID = 1
) Teams on TEams.GiftFactID = sub.GiftFactID_of_the_CashGift 
INNER JOIN
                      dbo.DIM_Appeal AS DIM_Appeal_1 ON sub.AppealIdentifier = DIM_Appeal_1.AppealIdentifier
inner join DIM_Date on sub.[DatedimID of gift] = dim_date.DateDimID 
LEFT OUTER JOIN
                          (SELECT     GiftFactID, GiftCodeDimID
                            FROM          dbo.FACT_Gift AS FACT_Gift_1
                            WHERE      (GiftCodeDimID > - 1)) AS AllGiftCodes ON AllGiftCodes.GiftFactID = sub.GiftFactID_of_the_CashGift 
LEFT OUTER JOIN dbo.DIM_GiftCode AS GCs ON GCs.GiftCodeDimID = AllGiftCodes.GiftCodeDimID  
left outer join
(
select 
GiftFactID,AttributeDescription as Product
from 
DIM_AppealAttribute
inner join DIM_Appeal on DIM_Appeal.AppealDimID = DIM_AppealAttribute.AppealDimID
inner join FACT_Gift on FACT_Gift.AppealDimID = DIM_Appeal.AppealDimID
where AttributeCategory = 'Product'
) AllProducts on AllProducts.GiftFactID = sub.GiftFactID_of_the_CashGift
left outer join --to find all target audiences, now including overriding ones!
(
select FACT_Gift.GiftFactID,
case when OverridingTargetAudiences.TargetAudience IS not null then OverridingTargetAudiences.TargetAudience
else DIM_AppealAttribute.AttributeDescription
end as TargetAudience 
from 
DIM_AppealAttribute
inner join DIM_Appeal on DIM_Appeal.AppealDimID = DIM_AppealAttribute.AppealDimID
inner join FACT_Gift on FACT_Gift.AppealDimID = DIM_Appeal.AppealDimID
left outer join
--THIS TO FIND OVERRIDING TARGET AUDIENCES PLACED ON GIFTS!
(
select GiftFactID,AttributeDescription as TargetAudience from FACT_GiftAttribute
where AttributeCategory = 'Target Audience'
and attributedescription is not null
) OverridingTargetAudiences on OverridingTargetAudiences.GiftFactID = FACT_Gift.GiftFactID
where AttributeCategory = 'Target Audience'
) AllTargetAudiences on AllTargetAudiences.GiftFactID = sub.GiftFactID_of_the_CashGift  

/*
Below is where to select date when checking/working on the script!
*/
--where dim_date.IsCurrentFiscalYear = 1
) as sub
LEFT OUTER JOIN
                      dbo.A_GM_Dashboards_KnownDescriptors ON 
                      dbo.A_GM_Dashboards_KnownDescriptors.GM_TIEStyle_CampaignDescriptor = sub.GM_TIEStyle_CampaignDescriptor
inner join DIM_Date on dim_date.DateDimID = sub.[DatedimID of gift]
) as MainSub
left outer join 
A_GM_DashBoards_Grouping 
on A_GM_DashBoards_Grouping.ID = MainSub.DashGroup
group by CalendarYearMonth,ID,FormsPartOf,Level,Description

union all

--step 5: ACTUAL RECEIVED VALUE of regular giving payments

--most if not all existing rules cannot be applied to payments currently, but hopefully don't need to be

--I believe this needs own fundamentally different set of rules so the rules starting R (only) are applied here:

--the inner query called 'RGSummary' tries to keep key info to help with any further development

select
'ActualReceivedRGIncome' as [Type],
CalendarYearMonth, 
rgsummary.ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]
from
(
select
'ActualReceivedRGIncome' as [Type],
MainSummary.CalendarYearMonth,
MainSummary.GM_TIEStyle_CampaignDescriptor,
MainSummary.PaymentType,
MainSummary.BeforeOrAfterApril,
MainSummary.GiftCode,
case
when GiftCode = 'SMS' then 69 --rule R25
WHEN 
MainSummary.GM_TIEStyle_CampaignDescriptor is not null 
AND
(
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Supporter Recruitment Team%'
	AND 
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'NULL%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Direct Marketing Team%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Sdev%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'SRec%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Supporter Development & Retention Team%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Digital Marketing Team%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Community Team%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Comm - Not Categorised%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Events Team%'
) then 998 --rule R26 part 1 of 3
when
(
MainSummary.GM_TIEStyle_CampaignDescriptor like 'Community Team%'
OR 
MainSummary.GM_TIEStyle_CampaignDescriptor like 'Comm - Not Categorised%'
)
AND 
GM_TIEStyle_CampaignDescriptor not like '%High Value%'
then 31 -- rule R26 part 2 of 3
when
MainSummary.GM_TIEStyle_CampaignDescriptor like 'Events Team%'
AND 
GM_TIEStyle_CampaignDescriptor not like '%High Value%'
then 27 -- rule R26 part 3 of 3
when GM_TIEStyle_CampaignDescriptor like '%Upgrade%' and PaymentType = 'Direct Debit' and (BeforeOrAfterApril  = 'Gift started during this financial year' or AmendedThisFYOrNot = 'Gift amended during this financial year') then 82 --rule R27
when GM_TIEStyle_CampaignDescriptor like '%Upgrade%' and PaymentType <> 'Direct Debit' and (BeforeOrAfterApril = 'Gift started during this financial year' or AmendedThisFYOrNot = 'Gift amended during this financial year') then 83 --rule R28
when GM_TIEStyle_CampaignDescriptor like '%High Value%' and PaymentType = 'Direct Debit' then 68 --rule R29
when GM_TIEStyle_CampaignDescriptor like '%High Value%' and PaymentType <> 'Direct Debit' then 76 --rule R30
when BeforeOrAfterApril = 'Gift started before this financial year' and PaymentType = 'Direct Debit' then 68 --rule R31
when BeforeOrAfterApril = 'Gift started before this financial year' and PaymentType <> 'Direct Debit' then 76 --rule R32
when BeforeOrAfterApril = 'Gift started during this financial year' and PaymentType = 'Direct Debit' then 80 --rule R33
when BeforeOrAfterApril = 'Gift started during this financial year' and PaymentType <> 'Direct Debit' then 81 --rule R34
end as ID,
Value as [Total]
from
(
	select *
	from 
	A_GM_REP_YTDSummary_RGPs_PaymentTypeVersion
) AS MainSummary
) RGSummary
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = RGSummary.ID
group by 
Type,
CalendarYearMonth,
RGsummary.ID,
FormsPartOf,
Level,
Description

union all

--step 6 - all event sign ups, these come from all the work in prestep 5 (in fact a physical table recreated then)

select
Type,
CalendarYearMonth,
ID,
FormsPartOf,
Level,
Description,
SUM(A_GM_DashBoards_EventSignUpsFullerInfo.Count) as [Total] --intellisense may not recognise column name yet - something that could be cleaned up easily
from A_GM_DashBoards_EventSignUpsFullerInfo
group by 
Type,
CalendarYearMonth,
ID,
FormsPartOf,
Level,
Description

union all

--step 7 - all pack requests, these come from all the work in prestep 6 (in fact a physical table recreated then)

select
Type,
CalendarYearMonth,
ID,
FormsPartOf,
Level,
Description,
SUM(SendsInMonth) as [Total]
from A_GM_DashBoards_PackRequestsFullerInfo
group by 
Type,
CalendarYearMonth,
ID,
FormsPartOf,
Level,
Description


--step x for now as helping to work out what to do with them - every single other gift type not already covered



--Targets

--this stage inserts into ##MainResultsTable with actual of 0 for any subsequent month in the current year (up to and including the current month!) where a gift has been made. This is because otherwise the YTD was not carrying across where there was money received in an earlier month but not in a later one, and also a related problem of targets not being found during the creation of #MonthlyActualsWorking where there was no actual for given month. 
insert into #MainResultsTable
select
SubToFindMissingRows.[Type],
SubToFindMissingRows.CalendarYearMonth,
SubToFindMissingRows.ID,
d.FormsPartOf,
d.Level,
d.Description,
0 as [Total]
from
(
		select * from
		(
		select distinct
		--PrimaryKeyWithValues.FiscalYear,
		AllPastMonths.CalendarYearMonth,
		PrimaryKeyWithValues.Type,
		PrimaryKeyWithValues.ID
		--0 as [Total]
		from
		(select distinct d.FiscalYear,m.CalendarYearMonth,m.type,m.ID,m.[Total]
		 from #MainResultsTable m inner join DIM_Date d on d.CalendarYearMonth = m.CalendarYearMonth)
		PrimaryKeyWithValues
		inner join
		(select distinct FiscalYear,CalendarYearMonth from DIM_Date
		where MonthsSince >-1) --needs to be minus TWO because when LOOKED AT on first day of a month, monthssince is still -1 since defined 10pm last night!!
		AllPastMonths
		on PrimaryKeyWithValues.FiscalYear = AllPastMonths.FiscalYear
		) sub
		except
		select
		CalendarYearMonth,
		Type,
		ID
		from #MainResultsTable
) SubToFindMissingRows
left outer join A_GM_DashBoards_Grouping d on d.ID = SubToFindMissingRows.ID


;

--Target comparison - This includes a 'current' YTD (i.e. not including YTD as at end of every month, and ONLY WORKING IT OUT FOR THE CURRENT YEAR AT PRESENT...) only not looking at current month for now (though we could? Or base on % of days that have passed - not really as fair as it sounds?) - I used CTE at first (first temp table) but it was not effective
--naturally keeps out booked future gifts which are always mistakes says Ado
;

select distinct --I THINK it must be right to do this distinct
R.*,
case 
	when r.CalendarYearMonth = (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsCurrentMonth,
case 
	when r.CalendarYearMonth > (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsFUTUREMonth,
case 
    when r.CalendarYearMonth IN (select CalendarYearMonth from DIM_Date where IsCurrentFiscalYear = 1) then 1 else 0
    end as IsInCurrentFY,
case when Target IS null then 0 else Target end as [Target], --so if no target assigned I give it zero, not return NULL,
--next two lines now compare values with no target to zero to give an accurate 'over/under' sum 
--BUT target field itself still remains null, so where a target was deliberately zero for given month, we know this
case when Target IS NULL then r.[Total] - 0
else r.[Total] - Target end AS [Over(Under)Target],
case 
	when Target is null Or Target = 0 then null 
	when [Total] IS null Or [Total] = 0 then null
	else 100*(r.[Total] - Target) / Target 
end as [%Over(Under)Target]
into #MonthlyActualsWorking
from 
#MainResultsTable R
full outer join
A_GM_Dashboards_Targets T 
on t.CalendarYearMonth = r.CalendarYearMonth
and t.ID = r.ID
and t.Type = r.Type
where 
(
r.CalendarYearMonth
>=
(
select min(calendaryearmonth) as EarliestTargetSet
from A_GM_Dashboards_Targets
)
)
OR 
(
t.CalendarYearMonth
>=
(
select min(calendaryearmonth) as EarliestTargetSet
from A_GM_Dashboards_Targets
)
)

;
--this stage inserts into #MonthlyActualsWorking every single target for future months of the current year
--it stores 'Total' and the two target comparison fields as NULL
--this allows quick calculation of 'whole year target' and enables us to quickly answer or graph targets for the whole year against actuals to date

insert into #MonthlyActualsWorking
select  
t.[TYPE],
t.CalendarYearMonth,
t.ID,
t.FormsPartOf,
t.Level,
t.Description,
0 as Total,
0 as IsCurrentMonth,
1 as IsFUTUREMonth,
1 as IsInCurrentFY,
case when t.Target IS null then 0 else t.Target end as Target, --in case there could be NULLs returned otherwise,
NULL as [Over(Under)Target],
NULL as [%Over(Under)Target]
from A_GM_Dashboards_Targets t
inner join (select distinct calendaryearmonth,MonthsSince from DIM_Date) d on d.CalendarYearMonth = t.CalendarYearMonth
--this next inner join deals with an absurdity on first day of every month where DIM_Date still says
--that monthssince = -1 because it is created at time of data import
--so this join checks that we are only importing combinations of Type,CalendarYearMonth,ID that do not already exist!
inner join
(
select  
[TYPE],
t.CalendarYearMonth,
t.ID
from A_GM_Dashboards_Targets t
inner join (select distinct calendaryearmonth,MonthsSince from DIM_Date) d on d.CalendarYearMonth = t.CalendarYearMonth
where d.MonthsSince<0
except 
select 
Type,
CalendarYearMonth,
id
from #MonthlyActualsWorking
) ValidityCheck 
on ValidityCheck.Type = t.Type
and ValidityCheck.CalendarYearMonth = t.CalendarYearMonth
and ValidityCheck.ID = t.ID
where d.MonthsSince<0
;
--this stage is just to make YTD targets for those with 0 income (currently for this fiscal year only)
--it then gets used after the join below

select 
TYPE,
ID,
--CalendarYearMonth,
SUM(Target) as YTDTarget
into #YTDTargetsWithZEROIncome
from
--Keeping this whole query as re-used below for now
(
	select 
	t.Type,
	t.ID,
	NULL as YTDActual,
	NULL as YTDTarget,
	null as [YTD_Over(Under)Target],
	NULL as [YTD_%Over(Under)Target],
	t.CalendarYearMonth,
	t.FormsPartOf,
	t.Level,
	t.Description,
	case when t.CalendarYearMonth = (select top 1 CalendarYearMonth from DIM_Date where IsCurrentDate = 1)
	then 1 else 0 end as IsCurrentMonth,
	0 as IsFUTUREMonth,
	0 as MonthActual,
	t.Target as Target,
	0-t.Target as [Over(Under)Target],
	null as [%Over(Under)Target]
	from A_GM_Dashboards_Targets T
	left outer join #MonthlyActualsWorking M 
	On m.ID = t.ID
	and m.Type = t.Type
	and m.CalendarYearMonth = t.CalendarYearMonth
	where m.ID is null
	and t.CalendarYearMonth in (select distinct CalendarYearMonth from DIM_Date where MonthsSince > -1 and CalendarYearMonth in (select CalendarYearMonth from #MonthlyActualsWorking))
) MainWorkings
where MainWorkings.CalendarYearMonth in
(
select distinct calendaryearmonth from DIM_Date where IsCurrentFiscalYear = 1
--and MonthsSince > -1
)
group by Type,ID

;

--main final comparison NOW STORED AS A_GM_DASHBOARDS_FullResults
;
delete from A_GM_DASHBOARDS_Results
;
declare @CurrentMonth int
set @CurrentMonth = (select Top 1 CalendarYearMonth from DIM_Date where IsCurrentMonth = 1)

insert into A_GM_DASHBOARDS_Results
select 
AllWorkingExceptSorting.*,
m.CalendarYearMonth,
m.FormsPartOf,
m.Level,
m.Description,
m.IsCurrentMonth,
m.IsFUTUREMonth,
m.[Total] as MonthActual,
m.Target,
m.[Over(Under)Target],
m.[%Over(Under)Target]
from
(
select
InitialSummary.*,
--next two lines now compare values with no target to zero to give an accurate 'over/under' sum 
--BUT target field itself still remains null, so where a target was deliberately zero for given month, we know this
case when YTDTarget IS NULL then YTDActual - 0
else YTDActual - YTDTarget END AS [YTD_Over(Under)Target],
case 
	when YTDTarget is null Or YTDTarget = 0 then null 
	when YTDActual IS null Or YTDActual = 0 then null
	else 100*((YTDActual - YTDTarget) / YTDTarget)
end as [YTD_%Over(Under)Target]

from
(
select
M.Type,
m.ID,
SUM
(
--this currently only allows months before the current one to count in YTD actuals, and no YTD will be returned for past years.
case when 
CalendarYearMonth < @CurrentMonth --using this definition for now - COULD change the variable to include current month if we are after day 15 or some other criteria!?
--and CalendarYearMonth IN (select distinct CalendarYearMonth from DIM_Date where IsCurrentFiscalYear = 1) dealt with by only allowing currentfiscalyear below
then Total
else 0 end
) as YTDActual,
SUM
(
--case means we add up all past months of this current YTD to find YTD target totals. So no YTD will be returned for past years.
case when 
CalendarYearMonth < @CurrentMonth --using this definition for now - COULD change the variable to include current month if we are after day 15 or some other criteria!?
--and CalendarYearMonth IN (select distinct CalendarYearMonth from DIM_Date where IsCurrentFiscalYear = 1) dealt with by only allowing currentfiscalyear below
then Target
else 0 end
) as YTDTarget
from #MonthlyActualsWorking M
where calendaryearmonth
in
(select distinct calendaryearmonth from DIM_Date where IsCurrentFiscalYear = 1
--and MonthsSince > 0
)
group by 
M.Type,
m.ID
) InitialSummary
) AllWorkingExceptSorting
inner join #MonthlyActualsWorking M 
on M.ID = AllWorkingExceptSorting.ID
and M.Type = AllWorkingExceptSorting.Type
--order by 
--case when [YTD_Over(Under)Target] is null then 99999999999 else 1 end, [YTD_Over(Under)Target]

union
--this union is just to find TARGETS with no actuals at all against them, I think it's right...

select 
t.Type,
t.ID,
NULL as YTDActual,
Y.YTDTarget as YTDTarget,
null as [YTD_Over(Under)Target],
NULL as [YTD_%Over(Under)Target],
t.CalendarYearMonth,
t.FormsPartOf,
t.Level,
t.Description,
case when t.CalendarYearMonth = (select top 1 CalendarYearMonth from DIM_Date where IsCurrentDate = 1)
then 1 else 0 end as IsCurrentMonth,
0 as IsFUTUREMonth,
0 as MonthActual,
t.Target as Target,
0-t.Target as [Over(Under)Target],
null as [%Over(Under)Target]
from A_GM_Dashboards_Targets T
left outer join #MonthlyActualsWorking M 
On m.ID = t.ID
and m.Type = t.Type
and m.CalendarYearMonth = t.CalendarYearMonth
left outer join #YTDTargetsWithZEROIncome Y
on Y.ID = t.ID
and y.Type = t.Type
where m.ID is null
and t.CalendarYearMonth in 
(select distinct CalendarYearMonth 
from 
DIM_Date 
where --MonthsSince > -1 and 
CalendarYearMonth in (select CalendarYearMonth from #MonthlyActualsWorking))


--things to consider: 

--any need to split by payment type

--any need to keep STOs and DDs separate from other forms of regular giving

--any hard deadline when we know it's not worth looking earlier than at all?



--group by rollup (FormsPartOf,ID)



/* ESTIMATING annual value of cancellations per appeal send made on basis of 'person's last appeal before they cancelled'
--Some of the higher ones are reactivation and similar, is that a timing thing or do they reactivate and then cancel that?
--currently only looks at most recent cancelled gift of each person - this could be changed...
select
UsingFullList.AppealIdentifier,
COUNT([Constituent ID]) as People,
SUM (GiftAmountAtCancellation) As AnnualValueCancelledGifts
into #MainFacts
from
(
select *,ROW_NUMBER() over (partition by [Constituent ID] order by AppealDate desc) As RowCounter
from
(
select CancelledGifts.*,A_GM_TBL_1M_ConstituentAppeals.AppealIdentifier,A_GM_TBL_1M_ConstituentAppeals.AppealDate
from
(
select [Constituent ID],giftfactID,AnnualAmount as GiftAmountAtCancellation,[gift status date] as MostRecentCancellationDate,GiftDate
from A_GM_GiftStatusDate
inner join FACT_Gift on FACT_Gift.GiftSystemID = A_GM_GiftStatusDate.[System Record ID]
where [Gift Status] in ('Cancelled','Terminated')
) CancelledGifts
inner join 
A_GM_TBL_1M_ConstituentAppeals
on A_GM_TBL_1M_ConstituentAppeals.constituentID = CancelledGifts.[Constituent ID]
and A_GM_TBL_1M_ConstituentAppeals.AppealDate < CancelledGifts.MostRecentCancellationDate
) FullList
) UsingFullList
where RowCounter = 1
and (UsingFullList.AppealIdentifier like '14%'
or UsingFullList.AppealIdentifier like '15%')
group by UsingFullList.AppealIdentifier
--order by SUM (GiftAmountAtCancellation) desc
;
select DIM_Appeal.appealidentifier,AppealDescription,count(constituentID) as PeopleSentNotDistinct,COUNT(distinct constituentid) as PeopleSentDistinct
into #PeopleSentToPerAppeal
from A_GM_TBL_1M_ConstituentAppeals
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = A_GM_TBL_1M_ConstituentAppeals.AppealIdentifier
group by DIM_Appeal.AppealIdentifier,AppealDescription
;
select 
AppealIdentifier,
AppealDescription,
AnnualValueCancelledGifts / PeopleSentNotDistinct as CancelledValuePerSend,
AnnualValueCancelledGifts / PeopleSentDistinct as CancelledValuePerDistinctSend,
PeopleSentNotDistinct,
PeopleSentDistinct
from
(
select 
#MainFacts.AppealIdentifier,
AppealDescription,
People,
AnnualValueCancelledGifts,
PeopleSentNotDistinct,
PeopleSentDistinct
from 
#MainFacts 
left outer join
#PeopleSentToPerAppeal
on #PeopleSentToPerAppeal.AppealIdentifier = #MainFacts.AppealIdentifier
) MainBit
order by CancelledValuePerSend desc,CancelledValuePerDistinctSend desc
*/






/* using mainresultstable to look at years only and rates of change of importance of different things
select 
Type,
FiscalYearEnding,
ID,
FormsPartOf,
Level,
Description,
SUM([Total]) as [Total]
from #MainResultsTable
inner join
(
select distinct calendaryearmonth,Fiscalyear as FiscalYearEnding
from DIM_Date
) DistinctMonths
on DistinctMonths.CalendarYearMonth = #MainResultsTable.CalendarYearMonth
group by 
Type,
FiscalYearEnding,
ID,
FormsPartOf,
Level,
Description
*/



drop table A_GM_Dashboards_FullResultsForLongTermTrends
;
select * into A_GM_Dashboards_FullResultsForLongTermTrends
from
(
select 
GETDATE() as DateStored,
r.*,
d.FiscalYear,
RIGHT(r.CalendarYearMonth,2) as CalendarMonthNumber,
DaysSinceMonthEnd.DaysSinceMonthEnd,
ROW_NUMBER()
over (partition by Type,ID
order by r.CalendarYearMonth) as Sequence

from
#MainResultsTable r
inner join 
(select distinct CalendarYearMonth,FiscalYear from DIM_Date) d 
on d.CalendarYearMonth = r.CalendarYearMonth
inner join 
(select calendaryearmonth,min(dayssince) as DaysSinceMonthEnd
from DIM_Date
group by calendaryearmonth) DaysSinceMonthEnd
on DaysSinceMonthEnd.CalendarYearMonth = r.CalendarYearMonth
--limiting to this so that we do not risk using significantly incomplete information
) Main
where DaysSinceMonthEnd > 15
and [Type] <> 'ActualReceivedRGIncome' --this would be useful but is currently calculated on currentFY to define cold, would need to revisit
;

--Secondary bit at the end to calculate the correct givers, gift and annual value of all gifts active at month end by dashID!

/*in order to do so we will need: 

--These fields
GM_TIEStyle_CampaignDescriptor
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments
Product
packagecategorydescription
AppealTypeFromAppealID
Various dashboard fields

--From these tables
1. A table of 'AllRGFacts' which I think boils down to 'VIEW_RG_History' with latest facts for each actual gift (some being from latest amendment!) joined to other tables to find product and targetaudience
2. A_GM_Dashboards_KnownDescriptors
3. A_GM_DashBoards_Grouping
*/

select
h.*,
a.Product,
PackageCategoryDescription,
DIM_Audience.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments, --this is the RIGHT place to take audience from (same with team) - it is flattened correctly including overrides to FACT_Gift!!!
case 
when substring(h.AppealIdentifier,3,4) = '/UPR' then 'Welcome' 
when substring(h.AppealIdentifier,3,3) = '/UP' then 'Non-Welcome upgrade appeal' 
when h.AppealIdentifier IN (select * from #AppealsToBeTreatedAsUpgrade) then 'Non-Welcome upgrade appeal'
else 'Other'
End as AppealTypeFromAppealID
into #WidenedRGHistory
from 
VIEW_RG_History h
left outer join DIM_Package p on p.PackageIdentifier = h.PackageIdentifier
left outer join DIM_Appeal a on a.AppealIdentifier = h.AppealIdentifier
inner join FACT_Gift on FACT_Gift.GiftFactID = h.GiftFactID_of_the_RG
left outer join DIM_Audience on DIM_Audience.AudienceDimID = FACT_Gift.AudienceDimID

--need to deal with these newly added products here and in main script!: PPC, PSMS - DRTV, Social Media Advertising and POSSIBLY 'Welcome Activity'
--select distinct product from #WidenedRGHistory

--dashboard assignment. This would need changing if the 'new RG' definition in main file ever changed...although it is not completely identical as it has to cover amends as well as new gifts
select 
SubToGetValues.*,
FormsPartOf,
Level,
Description
into #WidenedRGHistory_with_DashID
from
(
select
'Wider version of VIEW_RGHistory' as [Type],
h.*,
CalendarYearMonth,
case 
--HV re-jigged per Ado 12Feb16 - ignores team-campaign and rules now! Risk of some falling to 999?
WHEN 
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
and Product = 'Donor Reporting'
then 72
when
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter'
then 71
/* OLD WAY OF DEALING WITH HV HERE
--This first one moves ANY Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV AND the product is 'direct solicited donations' to 'HV Direct Solicited'.--This is because that means the person was account managed by HV, so anything they do is credited to that team!
--This is often LOST for amendments as target audience changes are not put on the amendment
WHEN 
TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' 
and Product = 'Direct Solicited Donations'
and RuleNumberToApply not IN ('17','18','19','23','24') then 73
*/
--new rules added 12Feb16 for IDs 52,63, 35 and 62, per Ado's description of how to find
when 
(h.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or h.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = 'Regular Gifts - Doordrop' 
then 52
when 
(h.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or h.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Hothouse','Regular Gifts - BRTV','Regular Gifts - Hothouse BRTV','Regular Gifts - Hothouse Door Drop')
then 63
when 
(h.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or h.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product in ('Regular Gifts - Inserts')
then 35
when 
(h.GM_TIEStyle_CampaignDescriptor like 'Supporter Recruitment%' 
or h.GM_TIEStyle_CampaignDescriptor like 'SRec%')
and Product = ('Regular Gifts - Word of Mouth')
then 62
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
--A couple of steps to cover RULE 4:
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
	when RuleNumberToApply = 4 and Product = 'PPC' then 45
	when RuleNumberToApply = 4 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 4 then 39
	when RuleNumberToApply = 21 and Product = 'PPC' then 45
	when RuleNumberToApply = 21 and Product = 'Social Media Advertising' then 61
	when RuleNumberToApply = 21 then 39
WHEN RuleNumberToApply = 5 Then 51 --No such thing as regular wahoo, so any would have to be shop
WHEN RuleNumberToApply = 6 and Product = 'PPC' then 45
when RuleNumberToApply = 6 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 6 THEN 54
--WHEN RuleNumberToApply = 7 and GiftCodeOfTheRG = 'SMS' then 55 --old version, has it been completely superseeded correctly by below?
WHEN RuleNumberToApply = 7 and Product = 'PSMS - DRTV' then 55
WHEN RuleNumberToApply = 7 then 33
when
	RuleNumberToApply in (17,18,19) 
	AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments  = 'High Value Supporter' 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN RuleNumberToApply in (17,18,19) then 72
--Rule21 dealt with 4 above
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Telephone') 
then 79
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 78
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Telephone') 
then 37
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Welcome'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 64
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Telephone') 
then 65
WHEN 
RuleNumberToApply = 23
and product = 'Regular Gifts - Upgrade and Reactivation'
and AppealTypeFromAppealID = 'Non-Welcome upgrade appeal'
and packagecategorydescription in ('Direct Mail','Direct Mail Reminder') 
then 66
When RuleNumberToApply = 23 then 50
--updated rule 20 in case it had been including PPC and/or facebook
WHEN RuleNumberToApply = 20 and Product = 'PPC' then 45
when RuleNumberToApply = 20 and Product = 'Social Media Advertising' then 61
WHEN RuleNumberToApply = 20 then 50
--rule 21 dealt along with rule 4 earlier on
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
when RuleNumberToApply = 24 then 49
WHEN RuleNumberToApply = 26 THEN 53 --Will be more complex than this in reality
else 999
end as ID
from #WidenedRGHistory h
left outer join A_GM_Dashboards_KnownDescriptors
on A_GM_Dashboards_KnownDescriptors.GM_TIEStyle_CampaignDescriptor = h.GM_TIEStyle_CampaignDescriptor
inner join DIM_Date d on d.DateDimID = h.[DatedimID of gift or amendment]
) SubToGetValues
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = subtogetvalues.ID








--amended existing part of file size work - basically replacing VIEW_RG_History with our version that now has more information in

select LatestSequence.*,pt.PaymentType,Amounts.ChangeInAnnualisedAmount
into #RegularGiftDetails
from
(
select distinct ConstituentID,r.GiftFactID_of_the_RG,d.CalendarYearMonth, ID, MAX(r.sequence) as LatestSequence
from #WidenedRGHistory_with_DashID r
inner join DIM_Date d on d.DateDimID = r.[DatedimID of gift or amendment]
group by ConstituentID,r.GiftFactID_of_the_RG,d.CalendarYearMonth, ID --so same gift will have multiple rows once for each ID as well as other factors here
) LatestSequence
inner join 
(
select GiftFactID_of_the_RG,Sequence,ChangeInAnnualisedAmount --this is populated with full amount for original gift
from #WidenedRGHistory_with_DashID
) Amounts 
on Amounts.GiftFactID_of_the_RG = LatestSequence.GiftFactID_of_the_RG
and Amounts.Sequence = LatestSequence.LatestSequence
inner join FACT_Gift on latestsequence.GiftFactID_of_the_RG = FACT_Gift.GiftFactID
inner join DIM_PaymentType PT on PT.PaymentTypeDimID = fact_gift.PaymentTypeDimID

--for checking
--select * from #RegularGiftDetails

;
--All regular gifts crossed with every single relevant month since that gift began (including first month)
--Commented out limiter to months from specific month can save time
--takes 105 seconds alone with limiter
select distinct GiftFactID_of_the_RG, CalendarYearMonth as EveryRelevantMonth
into #EveryMonthGiftMayHaveExisted
from 
(
select GiftFactID_of_the_RG, MIN(dim_date.calendaryearmonth) as GiftStartMonth
from
#WidenedRGHistory_with_DashID inner join DIM_Date on DIM_Date.DateDimID = #WidenedRGHistory_with_DashID.[DatedimID of gift or amendment]
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
r.ChangeInAnnualisedAmount as AnnualAmountAtEndThisMonth,
r.LatestSequence as LatestSequence,
r.id as DashID
into #RegularGivingResultsWithoutRemovingOutdatedAmendments
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
where [Gift Status] in ('Terminated','Canceled','Completed')
) Cancellations 
on Cancellations.GiftFactID = r.GiftFactID_of_the_RG
where 
Cancellations.MonthCancelled is null --i.e. still active now
or EveryRelevantMonth < Cancellations.MonthCancelled --i.e. had been cancelled during or since that month

;

--to make final totals - NOW STORED IN A_GM_Dashboards_RGFileSizeEndEachMonth
delete from A_GM_Dashboards_RGFileSizeEndEachMonth
;
insert into A_GM_Dashboards_RGFileSizeEndEachMonth
select CalendarYearMonth, DashID, COUNT (distinct ConstituentID) as Givers,COUNT (Distinct GiftFactID_of_the_RG) as Gifts,SUM(AnnualAmountAtEndThisMonth) as Value
from #RegularGivingResultsWithoutRemovingOutdatedAmendments
left outer join A_GM_DashBoards_Grouping
on A_GM_DashBoards_Grouping.ID = #RegularGivingResultsWithoutRemovingOutdatedAmendments.DashID
group by CalendarYearMonth, DashID
order by CalendarYearMonth,DashID asc

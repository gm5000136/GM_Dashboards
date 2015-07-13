--preprestep 1: appealidentifiers to be regarded as upgrade

select distinct AppealIdentifier 
into #AppealsToBeTreatedAsUpgrade
from DIM_Appeal
where AppealIdentifier like '%/u%'
and AppealIdentifier not like 'RA/%'
and AppealDescription not like '%Unallocated%'
and AppealDescription not like '%Unicef%'


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
dim_appeal.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor
into #AmendmentFacts
from VIEW_RG_History
inner join DIM_Date
on dim_date.DateDimID = VIEW_RG_History.[DatedimID of gift or amendment]
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier
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
dim_appeal.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor
into #CancellationFacts
from 
VIEW_RG_History
--left outer join A_GM_DashBoards_Grouping
--on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
inner join 
(select giftfactid,GiftSystemID from FACT_Gift where GiftTypeDimID in (8,30) and GiftStatusDimID in (3,5)) as AllCancelledRGsAllTypes on AllCancelledRGsAllTypes.GiftFactID = VIEW_RG_History.GiftFactID_of_the_RG
left outer join A_GM_GiftStatusDate 
on A_GM_GiftStatusDate.[System Record ID] = AllCancelledRGsAllTypes.GiftSystemID
and A_GM_GiftStatusDate.[Gift Status] in ('Terminated','Cancelled')
left outer join DIM_Date 
on [Gift Status Date] = ActualDateString
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier

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
dim_appeal.Audience as TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
VIEW_RG_History.GM_TIEStyle_CampaignDescriptor
into #NewRGFacts
from 
VIEW_RG_History
--left outer join A_GM_DashBoards_Grouping
--on A_GM_DashBoards_Grouping.ID = VIEW_RG_History.DashGroup
left outer join DIM_Date 
on VIEW_RG_History.[DatedimID of gift or amendment] = DIM_Date.DateDimID
left outer join DIM_Package on DIM_Package.PackageDescription = VIEW_RG_History.PackageDescription
inner join DIM_Appeal on DIM_Appeal.AppealIdentifier = VIEW_RG_History.AppealIdentifier
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



--step 1: new annualised value of regular gifts for each ID and each month

SELECT 
subtogetvalues.Type,
SubToGetValues.CalendarYearMonth,
SubToGetValues.ID,
FormsPartOf,
Level,
Description,
SUM([£]) as [£]

into #MainResultsTable

from
(
select
'AnnualValueOfNewRegularGifts' as [Type],
CalendarYearMonth,
case 
--This first one moves ANY Supporter Development Team Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV to 'HV Stewardship'. This is often LOST for amendments as target audience changes are not put on the amendment
WHEN MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Development%'
AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' and RuleNumberToApply not IN ('17','18','19','23') then 72
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
WHEN RuleNumberToApply = 5 THEN 0 --Shop related rules not created yet
WHEN RuleNumberToApply = 6 THEN 53 --Will be more complex than this in reality
--WHEN RuleNumberToApply = 7 and sub.GiftCode = 'SMS' then 55 --Will be more complex than this in reality --CANNOT DEAL WITH THIS YET SO THEY ALL GO TO DRTV FOR THE AMENDMENTS
WHEN RuleNumberToApply = 7 then 33 --Will be more complex than this in reality
WHEN RuleNumberToApply IN (4,21) THEN 39
when
	RuleNumberToApply in (17,18,19) 
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
WHEN RuleNumberToApply = 20 then 50
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72
when RuleNumberToApply = 24 then 49
else 999
end as ID,
[£]
from
(
	select
	n.CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	n.AppealTypeForUpgradesOnly as AppealTypeFromAppealID,
	PackageCategoryDescription,
	SUM(n.AnnualValue) as [£]
	from 
	#NewRGFacts N
	--where n.CalendarYearMonth > 201503
	group by 
	CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealTypeForUpgradesOnly,
	PackageCategoryDescription
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

union all

/* old step 1

select
'AnnualValueOfNewRegularGifts' as [Type],
CalendarYearMonth, 
ID,
FormsPartOf,
Level,
Description,
SUM(VIEW_RG_History.ChangeInAnnualisedAmount) as [£]
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
SUM([£]) as [£]
from
(
select
'AnnualValueOfChangesToRegularGifts' as [Type],
calendaryearmonth_of_amendment as CalendarYearMonth,
case 
--This first one moves ANY Supporter Development Team Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV to 'HV Stewardship'. This is often LOST for amendments as target audience changes are not put on the amendment
WHEN MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Development%'
AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' and RuleNumberToApply not IN ('17','18','19','23') then 72
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
WHEN RuleNumberToApply = 5 THEN 0 --Shop related rules not created yet
WHEN RuleNumberToApply = 6 THEN 53 --Will be more complex than this in reality
--WHEN RuleNumberToApply = 7 and sub.GiftCode = 'SMS' then 55 --Will be more complex than this in reality --CANNOT DEAL WITH THIS YET SO THEY ALL GO TO DRTV FOR THE AMENDMENTS
WHEN RuleNumberToApply = 7 then 33 --Will be more complex than this in reality
WHEN RuleNumberToApply IN (4,21) THEN 39
when
	RuleNumberToApply in (17,18,19) 
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
WHEN RuleNumberToApply = 20 then 50
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72
when RuleNumberToApply = 24 then 49
else 999
end as ID,
[£]
from
(
	select
	calendaryearmonth_of_amendment,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealType as AppealTypeFromAppealID,
	PackageCategoryDescription,
	SUM(ChangeInAnnualisedValueFromUpgrade) as [£]
	from 
	#AmendmentFacts
	--where calendaryearmonth_of_amendment > 201503
	group by 
	calendaryearmonth_of_amendment,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealType,
	PackageCategoryDescription
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
SUM([£]) as [£]
from
(
select
'AnnualValueCancelledThisMonth' as [Type],
CalendarYearMonth,
case 
--This first one moves ANY Supporter Development Team Gift, where not one of the HV groupings or the upgrade one (by rule), where the target audience IS HV to 'HV Stewardship'. This is often LOST for amendments as target audience changes are not put on the amendment
WHEN MainSummary.GM_TIEStyle_CampaignDescriptor like 'Supporter Development%'
AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' and RuleNumberToApply not IN ('17','18','19','23') then 72
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'Small Trusts'
	then 75
WHEN RuleNumberToApply = 5 THEN 0 --Shop related rules not created yet
WHEN RuleNumberToApply = 6 THEN 53 --Will be more complex than this in reality
--WHEN RuleNumberToApply = 7 and sub.GiftCode = 'SMS' then 55 --Will be more complex than this in reality --CANNOT DEAL WITH THIS YET SO THEY ALL GO TO DRTV FOR THE AMENDMENTS
WHEN RuleNumberToApply = 7 then 33 --Will be more complex than this in reality
WHEN RuleNumberToApply IN (4,21) THEN 39
when
	RuleNumberToApply in (17,18,19) 
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
WHEN RuleNumberToApply = 20 then 50
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
WHEN RuleNumberToApply = 24 AND TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments = 'High Value Supporter' then 72
when RuleNumberToApply = 24 then 49
else 999
end as ID,
[£]
from
(
	select
	c.CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	c.AppealTypeForUpgradesOnly as AppealTypeFromAppealID,
	PackageCategoryDescription,
	SUM(c.ValueCancelled) as [£]
	from 
	#CancellationFacts C
	--where c.CalendarYearMonth > 201503
	group by 
	CalendarYearMonth,
	GM_TIEStyle_CampaignDescriptor,
	Product,
	TargetAudienceOfAppeal_NB_NotStoredOnGiftForAmendments,
	AppealTypeForUpgradesOnly,
	PackageCategoryDescription
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
-1*(SUM(VIEW_RG_History.ChangeInAnnualisedAmount)) as [£]
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





--step 4: actual RG payments received by component





union all

--step 5: actual cash received by component

select
'ValueOfCashGifts' as [Type],
CalendarYearMonth, 
ID,
FormsPartOf,
Level,
Description,
SUM([£]) as [£]
from
(
select
CASE 
--This first one moves ANY Supporter Development Team Gift, where not one of the HV groupings (by rule), where the target audience IS HV to 'HV Stewardship'. Done because target audience is often overwritten
WHEN sub.GM_TIEStyle_CampaignDescriptor like 'Supporter Development%'
AND TargetAudience = 'High Value Supporter' and RuleNumberToApply not IN ('17','18','19')
then 72
WHEN RuleNumberToApply = 0 THEN DefaultGroupingID 
WHEN RuleNumberToApply IN (1, 2, 3) THEN 0 --Events and community rules not created yet
WHEN 
	RuleNumberToApply IN (4,21)
	And TargetAudience = 'Small Trusts'
	then 75
WHEN RuleNumberToApply IN (4,21) THEN 39
WHEN RuleNumberToApply = 5 THEN 0 --Shop related rules not created yet
WHEN RuleNumberToApply = 6 THEN 53 --Will be more complex than this in reality
WHEN RuleNumberToApply = 7 and sub.GiftCode = 'SMS' then 55 --Will be more complex than this in reality
WHEN RuleNumberToApply = 7 then 33 --Will be more complex than this in reality
WHEN 
	RuleNumberToApply in (17,18,19) 
	and Product = 'Direct Solicited Donations'
	then 73
WHEN RuleNumberToApply in (17,18,19) then 71
WHEN RuleNumberToApply = 20 then 50
--Rule 21 dealt with rule 4 above
WHEN RuleNumberToApply = 22 then 50
WHEN RuleNumberToApply = 23 then 50
WHEN RuleNumberToApply = 24 AND TargetAudience = 'High Value Supporter' then 72
when RuleNumberToApply = 24 then 49
ELSE 999 END AS DashGroup,
DIM_Date.CalendarYearMonth,
sub.GM_TIEStyle_CampaignDescriptor,
Amount as [£]
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
Here's where to select time
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
SUM([£]) as [£]
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
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Direct Marketing Tea-m%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Sdev%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'SRec%'
	AND
	MainSummary.GM_TIEStyle_CampaignDescriptor not like 'Supporter Development & Retention Team%'
) then 998 --rule R26
when GM_TIEStyle_CampaignDescriptor like '%Upgrade%' and PaymentType = 'Direct Debit' and (BeforeOrAfterApril  = 'Gift started during this financial year' or AmendedThisFYOrNot = 'Gift amended during this financial year') then 82 --rule R27
when GM_TIEStyle_CampaignDescriptor like '%Upgrade%' and PaymentType <> 'Direct Debit' and (BeforeOrAfterApril = 'Gift started during this financial year' or AmendedThisFYOrNot = 'Gift amended during this financial year') then 83 --rule R28
when GM_TIEStyle_CampaignDescriptor like '%High Value%' and PaymentType = 'Direct Debit' then 68 --rule R29
when GM_TIEStyle_CampaignDescriptor like '%High Value%' and PaymentType <> 'Direct Debit' then 76 --rule R30
when BeforeOrAfterApril = 'Gift started before this financial year' and PaymentType = 'Direct Debit' then 68 --rule R31
when BeforeOrAfterApril = 'Gift started before this financial year' and PaymentType <> 'Direct Debit' then 76 --rule R32
when BeforeOrAfterApril = 'Gift started during this financial year' and PaymentType = 'Direct Debit' then 80 --rule R33
when BeforeOrAfterApril = 'Gift started during this financial year' and PaymentType <> 'Direct Debit' then 81 --rule R34
end as ID,
Value as [£]
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





--step 6 for now as helping to work out what to do with them - every single other gift type not already covered















--Targets: doing two separate ways for now, can combine later

--Target Comparison 1 - month by month with no YTD aspect

/* commented out since forms part of below combined one

select 
R.*,
case 
	when r.CalendarYearMonth = (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsCurrentMonth,
case 
	when r.CalendarYearMonth > (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsFUTUREMonth,
Target,
r.[£] - Target AS [Over(Under)Target],
case 
	when Target is null Or Target = 0 then null 
	when [£] IS null Or [£] = 0 then null
	else 100*(r.[£] - Target) / Target 
end as [%Over(Under)Target]
from 
#MainResultsTable R
full outer join
A_GM_Dashboards_Targets T 
on t.CalendarYearMonth = r.CalendarYearMonth
and t.ID = r.ID
and t.Type = r.Type
where r.CalendarYearMonth
>=
(
select min(calendaryearmonth) as EarliestTargetSet
from A_GM_Dashboards_Targets
)

*/


--Target comparison 2 - This is a 'current' YTD (i.e. not including YTD as at end of every month...) only not looking at current month for now (though we could? Or base on % of days that have passed - not really as fair as it sounds?) - I used CTE but that's not necessarily best (CTE is literally the above monthly version). Based on existing table and temp table so is not slow
--naturally keeps out booked future gifts which are always mistakes says Ado
;
select 
R.*,
case 
	when r.CalendarYearMonth = (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsCurrentMonth,
case 
	when r.CalendarYearMonth > (select CalendarYearMonth from DIM_Date where IsCurrentDate = 1) then 1 else 0 
end as IsFUTUREMonth,
Target,
r.[£] - Target AS [Over(Under)Target],
case 
	when Target is null Or Target = 0 then null 
	when [£] IS null Or [£] = 0 then null
	else 100*(r.[£] - Target) / Target 
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

--this stage is just to make YTD targets for those with 0 income
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
(select distinct calendaryearmonth from DIM_Date where IsCurrentFiscalYear = 1
and MonthsSince > 0)
group by Type,ID

;

select 
AllWorkingExceptSorting.*,
m.CalendarYearMonth,
m.FormsPartOf,
m.Level,
m.Description,
m.IsCurrentMonth,
m.IsFUTUREMonth,
m.[£] as MonthActual,
m.Target,
m.[Over(Under)Target],
m.[%Over(Under)Target]
from
(
select
InitialSummary.*,
YTDActual - YTDTarget AS [YTD_Over(Under)Target],
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
SUM([£]) as YTDActual,
SUM(Target) as YTDTarget
from #MonthlyActualsWorking M
where calendaryearmonth
in
(select distinct calendaryearmonth from DIM_Date where IsCurrentFiscalYear = 1
and MonthsSince > 0)
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
and t.CalendarYearMonth in (select distinct CalendarYearMonth from DIM_Date where MonthsSince > -1 and CalendarYearMonth in (select CalendarYearMonth from #MonthlyActualsWorking))


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
SUM([£]) as [£]
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






/*
    Q1: Cohort-level engagement and outcome summary
    Grain: one row per (lender, cohort_month)

    A cohort is the calendar month of a mortgage's first email_sent event,
    not when the mortgage originated. I excluded mortgages with no email_sent
    from the cohort entirely.

    Events carry consumer_id but not mortgage_id for engagement types. Because
    a consumer can hold multiple mortgages, I routed engagement through the
    applicants table using consumer_id. If a consumer has two mortgages and
    clicks an email, that click is counted against both. I flagged this as a
    known limitation — fixing it properly would need more information about
    which mortgage each email was actually for.

    Data issues I found and handled:
    1. event_alias had two formats for the same event (email-sent vs email_sent).
       I normalised with replace() before categorising, otherwise ~40% of
       email_sent volume was being miscategorised as unknown.
    2. 23% of applicant records point to mortgages that do not exist in the
       mortgages table. Of those, 560 consumers have real events that cannot be
       attributed to any mortgage. Engagement and intent rates are likely
       understated as a result.
*/

with

first_email as (

    select
        e.event_mortgage_id as mortgage_id,
        min(e.event_created_date) as first_email_date,
        date_trunc('month', min(e.event_created_date)) as cohort_month

    from events e
    where replace(lower(e.event_alias), '-', '_') = 'email_sent'
      and e.event_mortgage_id is not null

    group by 1

),

cohort_base as (

    select
        m.mortgage_id,
        m.firm_alias as lender,
        m.mortgage_state,
        f.first_email_date,
        f.cohort_month

    from mortgages m
    left join first_email f
        on m.mortgage_id = f.mortgage_id

),

mortgage_consumers as (

    select
        a.applicant_mortgage_id as mortgage_id,
        a.applicant_consumer_id as consumer_id

    from applicants a
    inner join cohort_base c
        on a.applicant_mortgage_id = c.mortgage_id
    where c.first_email_date is not null

),

engagement_events as (

    select
        mc.mortgage_id,
        replace(lower(e.event_alias), '-', '_') as event_alias,
        datediff('month', c.first_email_date, e.event_created_date) + 1 as month_number

    from events e
    inner join mortgage_consumers mc
        on e.event_consumer_id = mc.consumer_id
    inner join cohort_base c
        on mc.mortgage_id = c.mortgage_id

    where replace(lower(e.event_alias), '-', '_') != 'email_sent'
      and datediff('month', c.first_email_date, e.event_created_date) + 1 between 1 and 3

),

mortgage_flags as (

    select
        mortgage_id,
        max(case when month_number = 1 then 1 else 0 end) as engaged_m1,
        max(case when month_number = 2 then 1 else 0 end) as engaged_m2,
        max(case when month_number = 3 then 1 else 0 end) as engaged_m3,
        max(case when month_number in (1,2,3) then 1 else 0 end) as engaged_m1_to_m3,
        max(case when event_alias = 'intent' then 1 else 0 end) as had_intent

    from engagement_events
    group by 1

),

mortgage_level as (

    select
        c.mortgage_id,
        c.lender,
        c.cohort_month,
        c.mortgage_state,
        coalesce(f.engaged_m1, 0) as engaged_m1,
        coalesce(f.engaged_m2, 0) as engaged_m2,
        coalesce(f.engaged_m3, 0) as engaged_m3,
        coalesce(f.engaged_m1_to_m3, 0) as engaged_m1_to_m3,
        coalesce(f.had_intent, 0) as had_intent

    from cohort_base c
    left join mortgage_flags f
        on c.mortgage_id = f.mortgage_id

    where c.first_email_date is not null

)

select
    lender,
    cohort_month,
    count(distinct mortgage_id) as total_mortgages,

    round(100.0 * sum(engaged_m1) / count(*), 1) as engagement_rate_m1,
    round(100.0 * sum(engaged_m2) / count(*), 1) as engagement_rate_m2,
    round(100.0 * sum(engaged_m3) / count(*), 1) as engagement_rate_m3,
    round(100.0 * sum(engaged_m1_to_m3) / count(*), 1) as engagement_rate_m1_to_m3,

    round(100.0 * sum(had_intent) / count(*), 1) as intent_rate,

    sum(case when mortgage_state = 'open' then 1 else 0 end) as total_open,
    sum(case when mortgage_state = 'switched' then 1 else 0 end) as total_switched,
    sum(case when mortgage_state = 'redeemed' then 1 else 0 end) as total_redeemed,

    round(100.0 * sum(case when mortgage_state = 'switched' then 1 else 0 end) / count(*), 1) as switch_rate,
    round(100.0 * sum(case when mortgage_state = 'redeemed' then 1 else 0 end) / count(*), 1) as redemption_rate

from mortgage_level
group by 1, 2
order by 1, 2
;

-- ─────────────────────────────────────────────────────────────────────────────
-- Outcome distribution rolled up by lender (run separately)
-- Shows overall switch and redemption rates per lender across all cohorts.
-- ─────────────────────────────────────────────────────────────────────────────

-- select
--     lender,
--     count(distinct mortgage_id)                                                               as total_mortgages,
--     sum(case when mortgage_state = 'open'     then 1 else 0 end)                             as total_open,
--     sum(case when mortgage_state = 'switched' then 1 else 0 end)                             as total_switched,
--     sum(case when mortgage_state = 'redeemed' then 1 else 0 end)                             as total_redeemed,
--     round(100.0 * sum(case when mortgage_state = 'open'     then 1 else 0 end) / count(*), 1) as open_rate,
--     round(100.0 * sum(case when mortgage_state = 'switched' then 1 else 0 end) / count(*), 1) as switch_rate,
--     round(100.0 * sum(case when mortgage_state = 'redeemed' then 1 else 0 end) / count(*), 1) as redemption_rate
-- from mortgage_level
-- group by 1
-- order by 1
-- ;
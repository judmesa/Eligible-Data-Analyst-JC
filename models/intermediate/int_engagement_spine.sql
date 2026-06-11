with cohorts as (
    select * from {{ ref('int_mortgage_cohorts') }}
    where first_email_date is not null  -- I need to add this to clean the final table and only include valid cohorts
),

-- get all consumers linked to each mortgage
mortgage_consumers as (
    select
        mortgage_id,
        consumer_id
    from {{ ref('stg_applicants') }}
),

engagement_events as (
    select
        mc.mortgage_id,
        e.event_alias,
        e.event_date,
        c.first_email_date,
        c.cohort_month,

        -- month after first email did this event occur
        datediff('month', c.first_email_date, e.event_date) + 1  as months_since_start

    from {{ ref('stg_events') }} e
    inner join mortgage_consumers mc
        on e.consumer_id = mc.consumer_id
    inner join cohorts c
        on mc.mortgage_id = c.mortgage_id
    where e.event_category = 'engagement'
),

mortgage_engagement as (
    select
        mortgage_id,
        cohort_month,

        max(case when months_since_start = 1 then 1 else 0 end)  as engaged_month_1,
        max(case when months_since_start = 2 then 1 else 0 end)  as engaged_month_2,
        max(case when months_since_start = 3 then 1 else 0 end)  as engaged_month_3,
        max(case when event_alias = 'intent'  then 1 else 0 end) as had_intent

    from engagement_events
    where months_since_start between 1 and 3
    group by 1, 2
)

select
    c.mortgage_id,
    c.lender,
    c.cohort_month,
    c.mortgage_state,
    c.first_email_date,

    coalesce(e.engaged_month_1, 0)  as engaged_month_1,
    coalesce(e.engaged_month_2, 0)  as engaged_month_2,
    coalesce(e.engaged_month_3, 0)  as engaged_month_3,
    coalesce(e.had_intent, 0)       as had_intent,

    -- engaged in ANY of months 1-3
    case
        when coalesce(e.engaged_month_1, 0) = 1
          or coalesce(e.engaged_month_2, 0) = 1
          or coalesce(e.engaged_month_3, 0) = 1
        then 1 else 0
    end                             as engaged_m1_to_m3

from {{ ref('int_mortgage_cohorts') }} c
left join mortgage_engagement e
    on c.mortgage_id = e.mortgage_id
where c.first_email_date is not null

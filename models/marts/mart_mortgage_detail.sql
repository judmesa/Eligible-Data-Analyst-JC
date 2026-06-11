-- Mortgage-level detail table.
-- Grain: one row per mortgage.
-- Use for ad-hoc analysis, segmentation and cohort deep-dives.

with cohorts as (
    select * 
    from {{ ref('int_mortgage_cohorts') }}
    where first_email_date is not null
),

spine as (
    select * 
    from {{ ref('int_engagement_spine') }}
),

funnel as (
    select * 
    from {{ ref('int_engagement_funnel') }}
),

-- resolve intent date via consumer (no mortgage_id on intent events)
mortgage_consumers as (
    select 
    mortgage_id, 
    consumer_id
    from {{ ref('stg_applicants') }}
),

intent_dates as (
    select
        mc.mortgage_id,
        min(e.event_date) as first_intent_date

    from {{ ref('stg_events') }} e
    inner join mortgage_consumers mc
        on e.consumer_id = mc.consumer_id
    where e.event_alias = 'intent'
    group by 1
)

select
    -- identifiers
    c.mortgage_id,
    c.lender,
    c.cohort_month,
    c.mortgage_state,
    c.expiry_date,
    c.closed_date,
    c.first_email_date,

    -- engagement flags
    s.engaged_month_1,
    s.engaged_month_2,
    s.engaged_month_3,
    s.engaged_m1_to_m3,
    s.had_intent,

    -- funnel
    f.reached_email_clicked,
    f.reached_logged_in,
    f.reached_subtopic_read,
    f.reached_start_review,
    f.reached_intent,
    f.funnel_stage_label,
    f.funnel_stage_reached,

    -- days to key milestones
    datediff('day', c.first_email_date, i.first_intent_date) as days_to_intent,
    datediff('day', c.first_email_date, c.closed_date)       as days_to_close,

    -- flag: intent before close (key signal)
    case
        when i.first_intent_date is not null
         and c.closed_date is not null
         and i.first_intent_date <= c.closed_date
        then 1 else 0
    end as intent_before_close

from cohorts c
left join spine s
    on c.mortgage_id = s.mortgage_id
left join funnel f
    on c.mortgage_id = f.mortgage_id
left join intent_dates i
    on c.mortgage_id = i.mortgage_id
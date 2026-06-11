-- Funnel stage reached per mortgage.
-- Mortgage-consumer relationship via applicants bridge table.

with mortgage_consumers as (
    select 
        mortgage_id, 
        consumer_id
    from {{ ref('stg_applicants') }}
),

cohorts as (
    select *
    from {{ ref('int_mortgage_cohorts') }}
    where first_email_date is not null
),

-- all events per mortgage via consumer
mortgage_events as (
    select
        mc.mortgage_id,
        e.event_alias,
        e.event_date,
        c.cohort_month,
        c.lender,
        datediff('month', c.first_email_date, e.event_date) + 1 as months_since_start
    from {{ ref('stg_events') }} e
    inner join mortgage_consumers mc on e.consumer_id = mc.consumer_id
    inner join cohorts c on mc.mortgage_id = c.mortgage_id
    where months_since_start between 1 and 3
),

-- flag each stage per mortgage
funnel_flags as (
    select
        mortgage_id,
        cohort_month,
        lender,

        max(case when event_alias = 'email_sent'    then 1 else 0 end) as reached_email_sent,
        max(case when event_alias = 'email_clicked' then 1 else 0 end) as reached_email_clicked,
        max(case when event_alias = 'logged_in'     then 1 else 0 end) as reached_logged_in,
        max(case when event_alias = 'subtopic_read' then 1 else 0 end) as reached_subtopic_read,
        max(case when event_alias = 'start_review'  then 1 else 0 end) as reached_start_review,
        max(case when event_alias = 'intent'        then 1 else 0 end) as reached_intent

    from mortgage_events
    group by 1, 2, 3
),

-- assign funnel stage (highest stage reached)
funnel_stage as (
    select
        mortgage_id,
        cohort_month,
        lender,

        reached_email_sent,
        reached_email_clicked,
        reached_logged_in,
        reached_subtopic_read,
        reached_start_review,
        reached_intent,

        case
            when reached_intent        = 1 then 6
            when reached_start_review  = 1 then 5
            when reached_subtopic_read = 1 then 4
            when reached_logged_in     = 1 then 3
            when reached_email_clicked = 1 then 2
            when reached_email_sent    = 1 then 1
            else                                0
        end as funnel_stage_reached,

        case
            when reached_intent        = 1 then 'intent'
            when reached_start_review  = 1 then 'start_review'
            when reached_subtopic_read = 1 then 'subtopic_read'
            when reached_logged_in     = 1 then 'logged_in'
            when reached_email_clicked = 1 then 'email_clicked'
            when reached_email_sent    = 1 then 'email_sent'
            else                                'no_engagement'
        end as funnel_stage_label

    from funnel_flags
)

select
    c.mortgage_id,
    c.lender,
    c.cohort_month,
    c.mortgage_state,
    coalesce(f.reached_email_sent,    0) as reached_email_sent,
    coalesce(f.reached_email_clicked, 0) as reached_email_clicked,
    coalesce(f.reached_logged_in,     0) as reached_logged_in,
    coalesce(f.reached_subtopic_read, 0) as reached_subtopic_read,
    coalesce(f.reached_start_review,  0) as reached_start_review,
    coalesce(f.reached_intent,        0) as reached_intent,
    coalesce(f.funnel_stage_reached,  0) as funnel_stage_reached,
    coalesce(f.funnel_stage_label, 'no_engagement') as funnel_stage_label

from {{ ref('int_mortgage_cohorts') }} c
left join funnel_stage f on c.mortgage_id = f.mortgage_id
where c.first_email_date is not null
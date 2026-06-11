-- Final cohort-level summary table.
-- Grain: one row per (lender, cohort_month).
-- This is the table analysts and dashboards query directly.
with spine as (
    select * from {{ ref('int_engagement_spine') }}
),

funnel as (
    select * from {{ ref('int_engagement_funnel') }}
),

joined as (
    select
        s.lender,
        s.cohort_month,
        s.mortgage_id,
        s.mortgage_state,
        s.engaged_month_1,
        s.engaged_month_2,
        s.engaged_month_3,
        s.engaged_m1_to_m3,
        s.had_intent,
        f.reached_email_clicked,
        f.reached_logged_in,
        f.reached_subtopic_read,
        f.reached_start_review,
        f.reached_intent,
        f.funnel_stage_label

    from spine s
    left join funnel f
        on s.mortgage_id = f.mortgage_id
)

select
    lender,
    cohort_month,

    -- volume
    count(distinct mortgage_id)                          as total_mortgages,

    -- engagement rates month by month
    round(100.0 * sum(engaged_month_1) / count(*), 1)   as engagement_rate_m1,
    round(100.0 * sum(engaged_month_2) / count(*), 1)   as engagement_rate_m2,
    round(100.0 * sum(engaged_month_3) / count(*), 1)   as engagement_rate_m3,
    round(100.0 * sum(engaged_m1_to_m3) / count(*), 1)  as engagement_rate_m1_to_m3,

    -- funnel stages
    sum(reached_email_clicked)                           as mortgages_clicked,
    sum(reached_logged_in)                               as mortgages_logged_in,
    sum(reached_subtopic_read)                           as mortgages_subtopic_read,
    sum(reached_start_review)                            as mortgages_start_review,
    sum(reached_intent)                                  as mortgages_intent,

    -- key rates
    round(100.0 * sum(had_intent) / count(*), 1)        as intent_rate,

    -- outcomes
    sum(case when mortgage_state = 'switched'  then 1 else 0 end) as total_switched,
    sum(case when mortgage_state = 'redeemed'  then 1 else 0 end) as total_redeemed,
    sum(case when mortgage_state = 'open'      then 1 else 0 end) as total_open,

    round(100.0 * sum(case when mortgage_state = 'switched'
        then 1 else 0 end) / count(*), 1)               as switch_rate,
    round(100.0 * sum(case when mortgage_state = 'redeemed'
        then 1 else 0 end) / count(*), 1)               as redemption_rate

from joined
group by 1, 2
order by 1, 2
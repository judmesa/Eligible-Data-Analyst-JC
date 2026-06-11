-- Cohort-level summary across *all* lenders.
-- Grain: one row per cohort_month.
-- Use this to identify global engagement trends over time.
select
    cohort_month,
    count(distinct mortgage_id)                          as total_mortgages,

    -- engagement rates
    round(100.0 * sum(engaged_month_1) / count(*), 1)   as engagement_rate_m1,
    round(100.0 * sum(engaged_month_2) / count(*), 1)   as engagement_rate_m2,
    round(100.0 * sum(engaged_month_3) / count(*), 1)   as engagement_rate_m3,
    round(100.0 * sum(engaged_m1_to_m3) / count(*), 1)  as engagement_rate_m1_to_m3,

    -- funnel
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

from {{ ref('int_engagement_spine') }}
left join {{ ref('int_engagement_funnel') }} using (mortgage_id)
group by 1
order by 1
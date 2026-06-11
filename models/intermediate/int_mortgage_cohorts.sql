-- Assign each mortgage to a cohort based on the month of its first email_sent.
with
    first_email as (

        select
            e.mortgage_id,
            min(e.event_date) as first_email_date,
            date_trunc('month', min(e.event_date)) as cohort_month

        from {{ ref('stg_events') }} e
        where e.event_alias = 'email_sent' and e.mortgage_id is not null
        group by 1

    )

select
    m.mortgage_id,
    m.lender,
    m.mortgage_type,
    m.mortgage_state,
    m.expiry_date,
    m.closed_date,
    f.first_email_date,
    f.cohort_month

from {{ ref('stg_mortgages') }} m
left join first_email f
    on m.mortgage_id = f.mortgage_id
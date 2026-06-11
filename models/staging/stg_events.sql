with source as (
    select *
    from {{ ref('events') }}
)

select
    event_id,
    event_consumer_id as consumer_id,
    event_mortgage_id as mortgage_id,
    cast(event_created_date as date) as event_date,
    event_alias,
    case when event_alias ='email_sent' then 'communication'
         when event_alias in ('email_clicked','logged_in','subtopic_read','start_review','intent') then 'engagement'
         else 'unknown'
         end as event_category,

--flag event of engagement wihout mortgage_id
    case when event_alias !='email_sent' and event_mortgage_id is null then true else false end as dq_engagement_no_mortgage
from source
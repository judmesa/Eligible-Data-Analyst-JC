with source as (
    select *
    from {{ ref('applicants') }}
)

select
    applicant_id,
    applicant_mortgage_id as mortgage_id,
    applicant_consumer_id as consumer_id
from source
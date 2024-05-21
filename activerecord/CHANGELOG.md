*   Optimize Active Record batching further when using ranges.

    E.g., tested on a PostgreSQL table with 10M records and batches of 10k records, the
    generation of relations for the 1000 batches was `x2.4` times faster (`5.6s` vs `2.3s`) and
    used `x900` less bandwidth (`180MB` vs. less than `0.2MB`).

    *Maxime Réty*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.

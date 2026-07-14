# Coding manual — 16 characters for the justice-concept dendrogram (E5.1)

Score each concept (taxon) on all 16 characters **in this order**, using **only the allowed tokens**.
Judge from the concept's canonical definition (typology_taxa.csv), not from how a teacher would use it.
When a character does not apply to a concept, use the "na"/"absent" token where provided; otherwise choose the closest state.

| # | Character | Allowed tokens | Meaning |
|---|-----------|----------------|---------|
| 1 | focus | `outcome` / `process` / `relationship` | Is the concept about *what people get*, *how it is decided*, or *how people stand toward one another*? |
| 2 | comparative | `comparative` / `noncomparative` | Does judging it require comparing persons to each other (vs. an absolute standard)? |
| 3 | temporal | `backward` / `forward` / `atemporal` | Does it look back (to desert/wrong), forward (to consequences/repair), or neither? |
| 4 | structure | `endstate` / `patterned` / `historical` | Nozick's trichotomy: judged by the final pattern of shares, by a patterning rule, or by the history of transactions? |
| 5 | currency | `resources` / `welfare` / `capability` / `opportunity` / `na` | If distributive: equality/distribution *of what*? `na` if not a distributive-currency concept. |
| 6 | need_sensitive | `yes` / `partial` / `no` | Does it make allocation depend on recipients' needs? |
| 7 | desert_sensitive | `yes` / `partial` / `no` | Does it make allocation depend on desert/contribution/effort? |
| 8 | equal_shares_default | `yes` / `no` | Is equal division its default/baseline? |
| 9 | remedial | `remedial` / `nonremedial` | Does it presuppose a prior wrong to be undone? |
| 10 | punishment | `yes` / `no` | Is it centrally about deserved punishment/sanction? |
| 11 | repair | `yes` / `no` | Is it centrally about repairing harm / restoring relationships? |
| 12 | voice | `central` / `peripheral` / `absent` | Role of participation/voice of those affected? |
| 13 | interpersonal_treatment | `yes` / `no` | Is dignity/respect in interpersonal treatment central to it? |
| 14 | transparency_info | `yes` / `no` | Is the provision of information/explanation/transparency central to it? |
| 15 | level | `micro` / `macro` / `both` | Does it operate mainly at the interpersonal level, the institutional/system level, or both? |
| 16 | scope | `domaingeneral` / `spherespecific` | Does it claim one criterion across all goods, or different criteria for different spheres? |

Output for each taxon: the 16 tokens in the order above (characters 1→16).

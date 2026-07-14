# Grafický manuál knihy (závazný pro všechny figury)

Odvozeno z oficiální vizuální identity MU (`zdrojove-texty/muni-brandcloud-export-20190322.pdf`,
`muni-ped-brandcloud-export-20190322.pdf`). Každá figura v knize se řídí tímto manuálem —
implementace: `analyzy/scripts/theme_book.R` (R) + hlavičky `.dot` souborů (Graphviz).

## Barvy

**Základ (MU):** MUNI modrá `#0000DC` · černá `#000000` · bílá `#FFFFFF`
**Fakultní akcent (PdF):** oranžová `#FF7300` (Pantone 1505)
**Šedé:** text sekundární `#6E6E6E` · linky/rámy `#B8B8B8` · světlé výplně `#EFEFEF`

### Fixní mapování rolí (NIKDY neměnit mezi figurami)

| Role | Barva | Kde |
|---|---|---|
| **Procedurální spravedlnost** | `#0000DC` MUNI modrá | kap. 2, 6, 7, 8, Příloha E — všude |
| **Rovnost (equality)** | `#FF7300` PdF oranžová | dtto |
| **Potřeby (needs)** | `#00AF3F` zelená (MU doplňková) | dtto |
| **Zásluhy (merit)** | `#9100DC` fialová (MU doplňková) | dtto |

**Rodiny typologie (kap. 2 + Příloha E):** distributivní `#FF7300` (rovnost/potřeby/zásluhy
jsou její jemnější členění — ladí s oranžovou rovností) · procedurální `#0000DC` (shodná
s principem) · interakční `#00AF3F` · rektifikační `#F01928` (MU červená) · makro `#767676`.

**Vesnice (kap. 5) = jejich vlastní jména:** Modrá `#0000DC` · Zelená `#00AF3F` ·
Oranžová `#FF7300` · Bílá `#FFFFFF` (rám `#6E6E6E`) · Červená `#F01928` · Žlutá `#FFD200`.

**Divergentní škála 1–7 (likert):** oranžová (`#FF7300`, nespravedlivé) → světle šedá
(`#EFEFEF`, střed) → MUNI modrá (`#0000DC`, spravedlivé). Sekvenční škály: bílá→MUNI modrá.

**Tiery srovnatelnosti (kap. 4/8):** Tier 1 `#0000DC` (plný) · Tier 2 `#FF7300` (světlejší
výplň `#FFD9B8`) · Tier 3 `#B8B8B8`/`#EFEFEF` · hranice škály: svislá červená čárkovaná `#F01928`.

## Typografie

- **Figury (osy, popisky, legendy): Arial/Helvetica** — MUNI brand font je verzálkový
  display font, pro datové popisky je nečitelný; patří JEN na titulku knihy (tam se používá).
- Základní velikost 12 pt (ggplot `base_size = 12`), popisky uzlů Graphviz 11 pt.
- Žádné nadpisy UVNITŘ obrázku (title/subtitle) — název nese popisek pod figurou
  (`*Figure X.Y.*`, 1–2 věty, zdroj). Výjimka: písmena panelů (A:, B:).

## Formát a kvalita

- PNG 300 dpi + (kde smysluplné) PDF vektor; šířka na celou sazbu ~ 2600–3200 px.
- Bílé pozadí, bez rámu kolem celé figury; mřížka jen vodorovná světlá (`#EFEFEF`).
- Barevná redundance: skupiny vždy ROZLIŠENÉ I POPISKEM/legendu (čitelnost černobíle
  a pro barvoslepé; modrá×oranžová×zelená×fialová se liší i světlostí).

## Zdroj pravdy

Každá figura MUSÍ být generovaná skriptem z dat/definic (Graphviz `.dot`, R skript,
notebook) — nikdy ručně kreslená ani AI-generovaná (výjimka: dekorativní obálka knihy,
která nenese žádná data). Regenerace všech: `analyzy/figures/render_figures.sh`.

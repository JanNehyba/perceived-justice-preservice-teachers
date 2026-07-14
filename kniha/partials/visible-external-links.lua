-- Make every external web link unmistakable in PDF output. Bare URLs are first
-- converted to real links (important for DOI/URL entries in the bibliography),
-- then the visible anchor is set in MUNI blue, underlined and followed by a
-- north-east arrow. Internal links and non-PDF output are left unchanged.

local function is_web_target(target)
  return target:match("^https?://") ~= nil
end

local function breakable_underlined_url(target)
  local chunks = pandoc.List()
  local current = ""
  for char in target:gmatch(".") do
    current = current .. char
    local natural_break = char:match("[/%.%-%_%?&=]") ~= nil
    if #current >= 20 or (#current >= 10 and natural_break) then
      chunks:insert(current)
      current = ""
    end
  end
  if current ~= "" then
    chunks:insert(current)
  end

  local latex = pandoc.List()
  for i, chunk in ipairs(chunks) do
    latex:insert(
      "\\textcolor{MUNIblue}{\\uline{\\nolinkurl{" .. chunk .. "}}}"
    )
    if i < #chunks then
      latex:insert("\\allowbreak{}")
    end
  end
  return table.concat(latex)
end

local function linkify_bare_url(el)
  local text = el.text
  local first = text:find("https?://")
  if not first then
    return nil
  end

  local before = text:sub(1, first - 1)
  local target = text:sub(first)
  local after = ""

  -- Markdown often keeps closing punctuation in the same Str node. It belongs
  -- outside the URI annotation (for example "(https://example.org)." ).
  while target:match("[%.,;:%)%]]$") do
    after = target:sub(-1) .. after
    target = target:sub(1, -2)
  end

  local out = pandoc.List()
  if before ~= "" then
    out:insert(pandoc.Str(before))
  end
  local link = pandoc.Link(target, target)
  link.classes:insert("bare-web-url")
  out:insert(link)
  if after ~= "" then
    out:insert(pandoc.Str(after))
  end
  return out
end

local function style_web_link(el)
  if not is_web_target(el.target) then
    return nil
  end

  local is_bare_url = false
  for _, class in ipairs(el.classes) do
    if class == "bare-web-url" then
      is_bare_url = true
      break
    end
  end

  local content = pandoc.List()
  if is_bare_url then
    -- Preserve the url package's discretionary break points. Rendering the URI
    -- as an ordinary Str inside \uline would create an unbreakable overfull line
    -- and could push the PDF annotation beyond the page boundary.
    content:insert(pandoc.RawInline("latex", breakable_underlined_url(el.target)))
    content:insert(pandoc.RawInline(
      "latex",
      "\\,\\textcolor{MUNIblue}{\\textsuperscript{\\ensuremath{\\nearrow}}}"
    ))
  else
    content:insert(pandoc.RawInline("latex", "\\textcolor{MUNIblue}{\\uline{"))
    content:extend(el.content)
    content:insert(pandoc.RawInline(
      "latex",
      "\\,\\textsuperscript{\\ensuremath{\\nearrow}}}}"
    ))
  end
  el.content = content
  return el
end

function Pandoc(doc)
  if not FORMAT:match("latex") then
    return doc
  end

  doc = doc:walk({ Str = linkify_bare_url })
  doc = doc:walk({ Link = style_web_link })
  return doc
end

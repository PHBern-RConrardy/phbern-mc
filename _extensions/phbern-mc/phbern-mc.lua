-- Transform :::phbern-mc blocks into interactive HTML/Reveal.js questions and
-- add a linked solutions appendix for Typst.

local solutions = pandoc.List:new()
local question_count = 0
local checked_box = "☒"
local unchecked_box = "☐"

local function has_class(element, class)
  for _, value in ipairs(element.classes) do
    if value == class then return true end
  end
  return false
end

local function html_escape(value)
  return value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    :gsub('"', "&quot;"):gsub("'", "&#39;")
end

local function render_html(blocks)
  return pandoc.write(pandoc.Pandoc(blocks), "html"):gsub("%s+$", "")
end

local function render_html_inlines(inlines)
  return render_html(pandoc.Blocks({ pandoc.Plain(inlines) }))
end

local function render_typst_inlines(inlines)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst"):gsub("%s+$", "")
end

local function without_box(inlines)
  local result, correct = pandoc.List:new(), nil
  for index, inline in ipairs(inlines) do
    if index == 1 and inline.t == "Str" and inline.text == checked_box then
      correct = true
    elseif index == 1 and inline.t == "Str" and inline.text == unchecked_box then
      correct = false
    elseif not (index == 2 and correct ~= nil and inline.t == "Space") then
      result:insert(inline)
    end
  end
  return correct, result
end

local function split_inline_feedback(inlines)
  local answer, feedback = pandoc.List:new(), pandoc.List:new()
  local target, found_separator = answer, false
  for _, inline in ipairs(inlines) do
    if not found_separator and inline.t == "Str" and inline.text == "::" then
      found_separator, target = true, feedback
    else
      target:insert(inline)
    end
  end
  while #answer > 0 and answer[#answer].t == "Space" do answer:remove(#answer) end
  while #feedback > 0 and feedback[1].t == "Space" do feedback:remove(1) end
  return answer, feedback
end

local function parse_question(div)
  local option_list_index = nil
  for index, block in ipairs(div.content) do
    if block.t == "BulletList" then option_list_index = index; break end
  end
  if option_list_index == nil then
    warn("phbern-mc: a question needs a bullet list of answers")
    return nil
  end

  local question = pandoc.List:new()
  for index = 1, option_list_index - 1 do question:insert(div.content[index]) end
  if #question == 0 then
    warn("phbern-mc: a question is missing its question text")
    return nil
  end

  local options = pandoc.List:new()
  for _, item in ipairs(div.content[option_list_index].content) do
    local first = item[1]
    if first == nil or (first.t ~= "Plain" and first.t ~= "Para") then
      warn("phbern-mc: every answer must start with [ ] or [x]")
      return nil
    end
    local correct, option_inlines = without_box(first.content)
    local answer, inline_feedback = split_inline_feedback(option_inlines)
    if correct == nil or #answer == 0 then
      warn("phbern-mc: every answer must start with [ ] or [x]")
      return nil
    end
    local feedback = pandoc.List:new()
    if #inline_feedback > 0 then feedback:insert(pandoc.Para(inline_feedback)) end
    for block_index = 2, #item do feedback:insert(item[block_index]) end
    options:insert({ answer = answer, correct = correct, feedback = feedback })
  end

  local mode = div.attributes["mode"] or (has_class(div, "phbern-mc-multiple") and "multiple" or "single")
  local correct_count = 0
  for _, option in ipairs(options) do if option.correct then correct_count = correct_count + 1 end end
  if #options == 0 or correct_count == 0 or (mode == "single" and correct_count ~= 1) then
    warn("phbern-mc: single questions need exactly one [x]; multiple questions need at least one [x]")
    return nil
  end

  question_count = question_count + 1
  local identifier = div.identifier
  if identifier == nil or identifier == "" then identifier = "phbern-mc-question-" .. question_count end
  return { identifier = identifier, question = question, options = options, mode = mode, number = question_count }
end

local function html_question(data)
  local input_type = data.mode == "multiple" and "checkbox" or "radio"
  local html = { '<div class="phbern-mc" id="', html_escape(data.identifier), '" data-mode="', data.mode, '">',
    '<fieldset class="phbern-mc__fieldset"><legend class="phbern-mc__question">', render_html(data.question),
    '</legend><ul class="phbern-mc__options">' }
  for index, option in ipairs(data.options) do
    local input_id = data.identifier .. "-option-" .. index
    html[#html + 1] = '<li class="phbern-mc__option" data-correct="' .. tostring(option.correct) .. '"><label for="' .. html_escape(input_id) .. '"><input id="' .. html_escape(input_id) .. '" type="' .. input_type .. '" name="' .. html_escape(data.identifier) .. '" data-correct="' .. tostring(option.correct) .. '"><span>' .. render_html_inlines(option.answer) .. '</span></label>'
    if #option.feedback > 0 then html[#html + 1] = '<div class="phbern-mc__feedback" hidden>' .. render_html(option.feedback) .. '</div>' end
    html[#html + 1] = '</li>'
  end
  html[#html + 1] = '</ul><div class="phbern-mc__actions"><button class="phbern-mc__check" type="button">Antwort prüfen</button></div><p class="phbern-mc__result" aria-live="polite"></p></fieldset></div>'
  return pandoc.RawBlock("html", table.concat(html))
end

local function linked_question(question, identifier, classes, link_text, link_target)
  local content = pandoc.List:new()
  for index, block in ipairs(question) do
    if index == #question and (block.t == "Para" or block.t == "Plain") then
      local inlines = pandoc.List:new()
      for _, inline in ipairs(block.content) do inlines:insert(inline) end
      inlines:insert(pandoc.Space())
      inlines:insert(pandoc.Link({ pandoc.Str("("), pandoc.Str(link_text), pandoc.Str(")") }, link_target))
      content:insert(block.t == "Para" and pandoc.Para(inlines) or pandoc.Plain(inlines))
    else
      content:insert(block)
    end
  end
  return pandoc.Div(content, pandoc.Attr(identifier, classes))
end

local function typst_question(data)
  local blocks = pandoc.List:new()
  blocks:insert(linked_question(data.question, data.identifier, { "phbern-mc-question" }, "Lösungen im Anhang", "#phbern-mc-solution-" .. data.number))
  local rows = pandoc.List:new()
  for _, option in ipairs(data.options) do
    local marker = data.mode == "single" and "#circle(radius: 0.32em, stroke: 0.8pt)" or "#rect(width: 0.68em, height: 0.68em, radius: 0.1em, stroke: 0.8pt)"
    rows:insert("[" .. marker .. "], [" .. render_typst_inlines(option.answer) .. "]")
  end
  blocks:insert(pandoc.RawBlock("typst", "#grid(\n  columns: (auto, 1fr),\n  column-gutter: 0.55em,\n  row-gutter: 0.45em,\n  " .. table.concat(rows, ",\n  ") .. ",\n)"))
  return blocks
end

local function solution_block(data)
  local blocks = pandoc.List:new()
  blocks:insert(linked_question(data.question, "phbern-mc-solution-" .. data.number, {}, "Zur Frage", "#" .. data.identifier))
  local rows = pandoc.List:new()
  for _, option in ipairs(data.options) do
    local filled = option.correct and ", fill: black" or ""
    local marker = data.mode == "single"
      and "#circle(radius: 0.32em, stroke: 0.8pt" .. filled .. ")"
      or "#rect(width: 0.68em, height: 0.68em, radius: 0.1em, stroke: 0.8pt" .. filled .. ")"
    local content = render_typst_inlines(option.answer)
    local feedback = {}
    for _, block in ipairs(option.feedback) do
      if block.t == "Para" or block.t == "Plain" then
        feedback[#feedback + 1] = render_typst_inlines(block.content)
      end
    end
    if #feedback > 0 then
      content = content .. " #h(0.5em) #emph[" .. table.concat(feedback, " ") .. "]"
    end
    rows:insert("[" .. marker .. "], [" .. content .. "]")
  end
  blocks:insert(pandoc.RawBlock("typst", "#grid(\n  columns: (auto, 1fr),\n  column-gutter: 0.55em,\n  row-gutter: 0.45em,\n  " .. table.concat(rows, ",\n  ") .. ",\n)"))
  return blocks
end

local function solution_appendix(include_title)
  local blocks = pandoc.List:new()
  if include_title then
    blocks:insert(pandoc.Header(1, { pandoc.Str("Lösungen") }, pandoc.Attr("phbern-mc-solutions")))
  end
  for _, solution in ipairs(solutions) do
    for _, block in ipairs(solution) do blocks:insert(block) end
  end
  return blocks
end

function Div(div)
  if has_class(div, "phbern-mc-solutions") then
    if FORMAT == "typst" then return nil end
    return {}
  end
  if not has_class(div, "phbern-mc") and not has_class(div, "phbern-mc-multiple") then return nil end
  local data = parse_question(div)
  if data == nil then return nil end
  if FORMAT == "typst" then solutions:insert(solution_block(data)); return typst_question(data) end
  if FORMAT:match("html") or FORMAT == "revealjs" then return html_question(data) end
  return nil
end

function Pandoc(document)
  if FORMAT ~= "typst" then return document end

  local blocks = pandoc.List:new()
  local inserted = false
  for _, block in ipairs(document.blocks) do
    if block.t == "Div" and has_class(block, "phbern-mc-solutions") then
      if not inserted and #solutions > 0 then
        for _, appendix_block in ipairs(solution_appendix(false)) do blocks:insert(appendix_block) end
      end
      inserted = true
    else
      blocks:insert(block)
    end
  end
  if #solutions > 0 and not inserted then
    for _, appendix_block in ipairs(solution_appendix(true)) do blocks:insert(appendix_block) end
  end
  document.blocks = blocks
  return document
end
